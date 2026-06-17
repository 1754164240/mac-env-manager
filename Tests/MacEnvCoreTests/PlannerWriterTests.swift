import XCTest
@testable import MacEnvCore

final class PlannerWriterTests: XCTestCase {
    func testScannerReadsManagedAndDotfileSourcesFromFakeHome() throws {
        let home = try TemporaryHome()
        try FileManager.default.createDirectory(atPath: home.path("bin"), withIntermediateDirectories: true)
        try home.write(".mac-env-manager/env.sh", """
        # >>> Mac Env Manager
        export JAVA_HOME='/Library/Java/Home'
        # <<< Mac Env Manager
        """)
        try home.write(".zshrc", """
        export IMPORT_ME=manual
        export PATH="/usr/local/bin:$HOME/bin:/definitely/missing:$PATH"
        eval "$(rbenv init -)"
        """)

        let snapshot = try ShellFileScanner(homeDirectory: home.url).scan()

        XCTAssertEqual(snapshot.variables.map(\.name).sorted(), ["IMPORT_ME", "JAVA_HOME"])
        XCTAssertEqual(snapshot.pathEntries.map(\.value), ["/usr/local/bin", "$HOME/bin", "/definitely/missing"])
        XCTAssertEqual(snapshot.pathEntries.map(\.existsOnDisk), [true, true, false])
        XCTAssertEqual(snapshot.sources.map(\.path).sorted(), [
            home.path(".mac-env-manager/env.sh"),
            home.path(".zshrc")
        ])
        XCTAssertEqual(snapshot.unmanagedLines.count, 1)
    }

    func testChangePlannerCreatesManagedFileAndSourceBlocks() throws {
        let home = try TemporaryHome()
        try home.write(".zshrc", "# existing\n")
        let planner = ChangePlanner(homeDirectory: home.url)
        let snapshot = EnvironmentSnapshot(
            variables: [
                EnvVariable(name: "JAVA_HOME", value: "/Library/Java/Home", source: .managed)
            ],
            pathEntries: [
                PathEntry(value: "/usr/local/bin", isEnabled: true)
            ],
            sources: [
                ShellSource(path: home.path(".zshrc"), isEnabled: true)
            ]
        )

        let changeSet = try planner.plan(snapshot: snapshot)

        XCTAssertEqual(changeSet.changes.map(\.path).sorted(), [
            home.path(".mac-env-manager/env.sh"),
            home.path(".zshrc")
        ])
        XCTAssertTrue(changeSet.combinedDiff.contains("export JAVA_HOME='/Library/Java/Home'"))
        XCTAssertTrue(changeSet.combinedDiff.contains("source '\(home.path(".mac-env-manager/env.sh"))'"))
        XCTAssertEqual(changeSet.sourceCommands, ["source \(home.path(".zshrc"))"])
    }

    func testScannerDisablesDuplicatePathEntriesByDefault() throws {
        let home = try TemporaryHome()
        try home.write(".zprofile", """
        export PATH="$HOME/.local/bin:$HOME/.local/bin:$HOME/.local/bin:$PATH"
        """)

        let snapshot = try ShellFileScanner(homeDirectory: home.url).scan()

        XCTAssertEqual(snapshot.pathEntries.map(\.value), ["$HOME/.local/bin", "$HOME/.local/bin", "$HOME/.local/bin"])
        XCTAssertEqual(snapshot.pathEntries.map(\.isDuplicate), [false, true, true])
        XCTAssertEqual(snapshot.pathEntries.map(\.isEnabled), [true, false, false])
    }

    func testScannerPreservesEveryPathSettingSourceLine() throws {
        let home = try TemporaryHome()
        try home.write(".zshrc", """
        export PATH="/usr/local/bin:$PATH"
        export OTHER=value
        PATH="$HOME/bin:/opt/tools:$PATH"
        """)
        try home.write(".zprofile", """
        PATH="/zprofile/bin:$PATH"
        """)

        let snapshot = try ShellFileScanner(homeDirectory: home.url).scan()

        XCTAssertEqual(snapshot.pathEntries.map(\.value), [
            "/usr/local/bin",
            "$HOME/bin",
            "/opt/tools",
            "/zprofile/bin"
        ])
        XCTAssertEqual(snapshot.pathEntries.map(\.sourcePath), [
            home.path(".zshrc"),
            home.path(".zshrc"),
            home.path(".zshrc"),
            home.path(".zprofile")
        ])
        XCTAssertEqual(snapshot.pathEntries.map(\.lineNumber), [1, 3, 3, 1])
        XCTAssertEqual(snapshot.pathEntries.map(\.rawLine), [
            "export PATH=\"/usr/local/bin:$PATH\"",
            "PATH=\"$HOME/bin:/opt/tools:$PATH\"",
            "PATH=\"$HOME/bin:/opt/tools:$PATH\"",
            "PATH=\"/zprofile/bin:$PATH\""
        ])
    }

    func testImportableDotfileVariableIsNotManagedUntilTakeover() throws {
        let home = try TemporaryHome()
        let zshrc = home.path(".zshrc")
        try home.write(".zshrc", "export IMPORT_ME=manual\n")
        let planner = ChangePlanner(homeDirectory: home.url)
        let importable = EnvVariable(name: "IMPORT_ME", value: "manual", source: .dotfile(zshrc))

        var changeSet = try planner.plan(snapshot: EnvironmentSnapshot(
            variables: [importable],
            sources: [ShellSource(path: zshrc, isEnabled: true)]
        ))

        let managedChange = try XCTUnwrap(changeSet.changes.first { $0.path.hasSuffix(".mac-env-manager/env.sh") })
        XCTAssertFalse(managedChange.updated.contains("IMPORT_ME"))

        var takenOver = importable
        takenOver.isTakenOver = true
        changeSet = try planner.plan(snapshot: EnvironmentSnapshot(
            variables: [takenOver],
            sources: [ShellSource(path: zshrc, isEnabled: true)]
        ))

        let takenOverManagedChange = try XCTUnwrap(changeSet.changes.first { $0.path.hasSuffix(".mac-env-manager/env.sh") })
        let zshChange = try XCTUnwrap(changeSet.changes.first { $0.path == zshrc })
        XCTAssertTrue(takenOverManagedChange.updated.contains("export IMPORT_ME='manual'"))
        XCTAssertTrue(zshChange.updated.contains("# Mac Env Manager takeover: export IMPORT_ME=manual"))
    }

    func testWriterCreatesBackupsAndAppliesAtomically() throws {
        let home = try TemporaryHome()
        try home.write(".zshrc", "# existing\n")
        let path = home.path(".zshrc")
        let changeSet = ChangeSet(
            changes: [
                FileChange(path: path, original: "# existing\n", updated: "# changed\n", diff: "- # existing\n+ # changed\n")
            ],
            sourceCommands: ["source \(path)"]
        )

        let result = try ShellFileWriter(backupStore: BackupStore(rootDirectory: home.url)).apply(changeSet: changeSet)

        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "# changed\n")
        XCTAssertEqual(result.sourceCommands, ["source \(path)"])
        XCTAssertEqual(result.backups.count, 1)
        XCTAssertEqual(try String(contentsOfFile: result.backups[0].backupPath, encoding: .utf8), "# existing\n")
    }

    func testBackupStoreRestoresOriginalFile() throws {
        let home = try TemporaryHome()
        let path = home.path(".zprofile")
        try home.write(".zprofile", "before\n")
        let store = BackupStore(rootDirectory: home.url)
        let record = try store.backup(fileAtPath: path)
        try "after\n".write(toFile: path, atomically: true, encoding: .utf8)

        try store.restore(record)

        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "before\n")
    }

    func testBackupStoreListsMetadataRecords() throws {
        let home = try TemporaryHome()
        let path = home.path(".zshrc")
        try home.write(".zshrc", "before\n")
        let store = BackupStore(rootDirectory: home.url)
        let record = try store.backup(fileAtPath: path)

        let records = try store.listBackups()

        XCTAssertEqual(records, [record])
    }

    func testAppliedManagedFileCanBeSourcedByZshAndBash() throws {
        let home = try TemporaryHome()
        try home.write(".zshrc", "# zsh\n")
        try home.write(".bash_profile", "# bash\n")
        let snapshot = EnvironmentSnapshot(
            variables: [
                EnvVariable(name: "SMOKE_VAR", value: "hello world", source: .managed)
            ],
            pathEntries: [
                PathEntry(value: "/opt/smoke/bin", isEnabled: true)
            ],
            sources: [
                ShellSource(path: home.path(".zshrc"), isEnabled: true),
                ShellSource(path: home.path(".bash_profile"), isEnabled: true)
            ]
        )

        let changeSet = try ChangePlanner(homeDirectory: home.url).plan(snapshot: snapshot)
        _ = try ShellFileWriter(backupStore: BackupStore(rootDirectory: home.url)).apply(changeSet: changeSet)
        let managedPath = home.path(".mac-env-manager/env.sh")

        XCTAssertEqual(try runShell("/bin/zsh", sourcePath: managedPath), "hello world|/opt/smoke/bin")
        XCTAssertEqual(try runShell("/bin/bash", sourcePath: managedPath), "hello world|/opt/smoke/bin")
    }
}

private func runShell(_ shell: String, sourcePath: String) throws -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: shell)
    process.arguments = ["-c", "source '\(sourcePath)'; printf '%s|%s' \"$SMOKE_VAR\" \"${PATH%%:*}\""]
    process.standardOutput = output
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}
