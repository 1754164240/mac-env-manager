import Foundation

public struct ShellFileWriter {
    public var backupStore: BackupStore
    public var fileManager: FileManager

    public init(backupStore: BackupStore = BackupStore(), fileManager: FileManager = .default) {
        self.backupStore = backupStore
        self.fileManager = fileManager
    }

    public func apply(changeSet: ChangeSet) throws -> ApplyResult {
        var backups: [BackupRecord] = []

        for change in changeSet.changes where change.original != change.updated {
            let current = fileManager.fileExists(atPath: change.path)
                ? try String(contentsOfFile: change.path, encoding: .utf8)
                : ""
            guard current == change.original else {
                throw MacEnvError.originalContentChanged(change.path)
            }
        }

        for change in changeSet.changes where change.original != change.updated {
            backups.append(try backupStore.backup(fileAtPath: change.path))
            try writeAtomically(change.updated, toPath: change.path)
        }

        return ApplyResult(backups: backups, sourceCommands: changeSet.sourceCommands)
    }

    private func writeAtomically(_ content: String, toPath path: String) throws {
        let destination = URL(fileURLWithPath: path)
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporaryURL = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        try content.write(to: temporaryURL, atomically: true, encoding: .utf8)

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: destination)
        }
    }
}
