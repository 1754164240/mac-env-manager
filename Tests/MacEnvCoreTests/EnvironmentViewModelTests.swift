import XCTest
@testable import MacEnvCore

@MainActor
final class EnvironmentViewModelTests: XCTestCase {
    func testViewModelKeepsSensitiveValuesPlaintextAndPlansChanges() throws {
        let home = try TemporaryHome()
        try home.write(".zshrc", "# shell\n")
        let viewModel = EnvironmentViewModel(homeDirectory: home.url)

        viewModel.snapshot = EnvironmentSnapshot(
            variables: [
                EnvVariable(name: "OPENAI_API_KEY", value: "sk-proj-visible", source: .managed)
            ],
            pathEntries: [],
            sources: [
                ShellSource(path: home.path(".zshrc"), isEnabled: true)
            ]
        )

        try viewModel.rebuildPlan()

        XCTAssertEqual(viewModel.displayValue(for: viewModel.snapshot.variables[0]), "sk-proj-visible")
        XCTAssertTrue(viewModel.pendingDiff.contains("OPENAI_API_KEY"))
        XCTAssertEqual(viewModel.sourceCommands, ["source \(home.path(".zshrc"))"])
        XCTAssertTrue(viewModel.warnings.contains { $0.contains("OPENAI_API_KEY") })
    }

    func testTakeoverMovesImportableVariableToManagedSource() throws {
        let home = try TemporaryHome()
        let viewModel = EnvironmentViewModel(homeDirectory: home.url)
        let zshrc = home.path(".zshrc")
        viewModel.snapshot = EnvironmentSnapshot(
            variables: [
                EnvVariable(name: "IMPORT_ME", value: "manual", isExported: true, isEnabled: true, source: .dotfile(zshrc))
            ]
        )

        viewModel.takeOver(variableID: viewModel.snapshot.variables[0].id)

        XCTAssertEqual(viewModel.snapshot.variables[0].source, .dotfile(zshrc))
        XCTAssertTrue(viewModel.snapshot.variables[0].isTakenOver)
    }

    func testViewModelUpdatesPathEntry() throws {
        let home = try TemporaryHome()
        let viewModel = EnvironmentViewModel(homeDirectory: home.url)
        let entry = PathEntry(value: "/old/bin", isEnabled: true)
        viewModel.snapshot = EnvironmentSnapshot(pathEntries: [entry])

        var updated = entry
        updated.value = "/new/bin"
        updated.isEnabled = false
        viewModel.updatePathEntry(updated)

        XCTAssertEqual(viewModel.snapshot.pathEntries[0].value, "/new/bin")
        XCTAssertFalse(viewModel.snapshot.pathEntries[0].isEnabled)
    }

    func testViewModelLoadsAndRestoresBackups() throws {
        let home = try TemporaryHome()
        let path = home.path(".zshrc")
        try home.write(".zshrc", "before\n")
        let store = BackupStore(rootDirectory: home.url)
        let record = try store.backup(fileAtPath: path)
        try "after\n".write(toFile: path, atomically: true, encoding: .utf8)
        let viewModel = EnvironmentViewModel(homeDirectory: home.url)

        try viewModel.loadBackups()
        viewModel.selectedBackupID = record.id
        try viewModel.restoreSelectedBackup()

        XCTAssertEqual(viewModel.backupRecords, [record])
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "before\n")
    }

    func testLoadAsyncPopulatesSnapshotWithoutLeavingLoadingState() async throws {
        let home = try TemporaryHome()
        try home.write(".zshrc", "export ASYNC_VAR=ready\n")
        let viewModel = EnvironmentViewModel(homeDirectory: home.url)

        await viewModel.loadAsync()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.snapshot.variables.map(\.name), ["ASYNC_VAR"])
        XCTAssertFalse(viewModel.pendingDiff.isEmpty)
    }

    func testPathDiagnosticsShowDuplicateAndMissingPath() throws {
        let home = try TemporaryHome()
        let viewModel = EnvironmentViewModel(homeDirectory: home.url)
        viewModel.snapshot = EnvironmentSnapshot(
            pathEntries: [
                PathEntry(value: "/usr/bin", isEnabled: true, isDuplicate: false, existsOnDisk: true),
                PathEntry(value: "/usr/bin", isEnabled: true, isDuplicate: true, existsOnDisk: true),
                PathEntry(value: "/missing/path", isEnabled: true, isDuplicate: false, existsOnDisk: false)
            ]
        )

        XCTAssertEqual(viewModel.pathDiagnostics, [
            "PATH 重复：/usr/bin",
            "PATH 不存在：/missing/path"
        ])
    }

    func testViewModelDistinguishesInitializationSuggestionsFromUserEdits() throws {
        let home = try TemporaryHome()
        let viewModel = EnvironmentViewModel(homeDirectory: home.url)
        viewModel.pendingChangeSet = ChangeSet(
            changes: [
                FileChange(path: home.path(".zshrc"), original: "", updated: "source managed\n", diff: "+ source managed")
            ]
        )

        XCTAssertEqual(viewModel.pendingChangeCount, 1)
        XCTAssertFalse(viewModel.hasUserEdits)

        viewModel.addVariable()

        XCTAssertTrue(viewModel.hasUserEdits)
    }

    func testSelectedSourceDetailReadsFileContentAndRelatedPathLines() throws {
        let home = try TemporaryHome()
        try home.write(".zshrc", """
        export PATH="$PATH:/Users/shenyang/.lmstudio/bin"
        export FOO=bar
        export PATH="$HOME/.local/bin:$PATH"
        """)
        let zshrc = home.path(".zshrc")
        let viewModel = EnvironmentViewModel(homeDirectory: home.url)
        viewModel.snapshot = EnvironmentSnapshot(
            pathEntries: [
                PathEntry(
                    value: "/Users/shenyang/.lmstudio/bin",
                    sourcePath: zshrc,
                    lineNumber: 1,
                    rawLine: "export PATH=\"$PATH:/Users/shenyang/.lmstudio/bin\""
                ),
                PathEntry(
                    value: "$HOME/.local/bin",
                    sourcePath: zshrc,
                    lineNumber: 3,
                    rawLine: "export PATH=\"$HOME/.local/bin:$PATH\""
                )
            ],
            sources: [
                ShellSource(path: zshrc, isEnabled: true, hasManagedBlock: false, importableCount: 1, unmanagedCount: 0)
            ]
        )
        viewModel.selectedSourcePath = zshrc

        let detail = try XCTUnwrap(viewModel.selectedSourceDetail)

        XCTAssertEqual(detail.source.path, zshrc)
        XCTAssertTrue(detail.content.contains("export FOO=bar"))
        XCTAssertEqual(detail.pathLines.map(\.lineNumber), [1, 3])
        XCTAssertEqual(detail.pathLines.map(\.rawLine), [
            "export PATH=\"$PATH:/Users/shenyang/.lmstudio/bin\"",
            "export PATH=\"$HOME/.local/bin:$PATH\""
        ])
    }

    func testViewModelStoresSelectedRepairAppAndCommandPreview() throws {
        let home = try TemporaryHome()
        let viewModel = EnvironmentViewModel(homeDirectory: home.url)

        viewModel.selectRepairApp(URL(fileURLWithPath: "/Applications/Mac Env Manager.app"))

        XCTAssertEqual(viewModel.selectedRepairPlan?.displayName, "Mac Env Manager.app")
        XCTAssertEqual(
            viewModel.selectedRepairPlan?.terminalCommand,
            "sudo xattr -rd com.apple.quarantine '/Applications/Mac Env Manager.app'"
        )
        XCTAssertNil(viewModel.repairMessage)
    }

    func testViewModelReportsInvalidRepairSelection() throws {
        let home = try TemporaryHome()
        let viewModel = EnvironmentViewModel(homeDirectory: home.url)

        viewModel.selectRepairApp(URL(fileURLWithPath: "/Applications/README.txt"))

        XCTAssertNil(viewModel.selectedRepairPlan)
        XCTAssertEqual(viewModel.errorMessage, "请选择 .app 应用程序：/Applications/README.txt")
    }
}
