import Foundation

public struct BackupStore {
    public var rootDirectory: URL
    public var fileManager: FileManager

    public init(rootDirectory: URL = FileManager.default.homeDirectoryForCurrentUser, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
    }

    public var backupsDirectory: URL {
        rootDirectory
            .appendingPathComponent(".mac-env-manager", isDirectory: true)
            .appendingPathComponent("backups", isDirectory: true)
    }

    public func backup(fileAtPath path: String, date: Date = Date()) throws -> BackupRecord {
        try fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
        let sourceURL = URL(fileURLWithPath: path)
        let normalizedDate = Date(timeIntervalSince1970: floor(date.timeIntervalSince1970))
        let timestamp = BackupStore.timestampFormatter.string(from: normalizedDate)
        let backupName = "\(sourceURL.lastPathComponent).\(timestamp).bak"
        let backupURL = backupsDirectory.appendingPathComponent(backupName)
        let metadataURL = backupURL.appendingPathExtension("json")

        if fileManager.fileExists(atPath: path) {
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: sourceURL, to: backupURL)
        } else {
            try Data().write(to: backupURL)
        }

        let record = BackupRecord(originalPath: path, backupPath: backupURL.path, createdAt: normalizedDate)
        let metadata = try JSONEncoder.macEnvManager.encode(record)
        try metadata.write(to: metadataURL, options: .atomic)
        return record
    }

    public func listBackups() throws -> [BackupRecord] {
        guard fileManager.fileExists(atPath: backupsDirectory.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: nil)
        return try urls.filter { $0.pathExtension == "json" }.map { url in
            let data = try Data(contentsOf: url)
            return try JSONDecoder.macEnvManager.decode(BackupRecord.self, from: data)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    public func listLegacyBackupFiles() throws -> [BackupRecord] {
        guard fileManager.fileExists(atPath: backupsDirectory.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: [.creationDateKey])
        return try urls.filter { $0.pathExtension != "json" }.map { url in
            let values = try url.resourceValues(forKeys: [.creationDateKey])
            let originalName = url.lastPathComponent.components(separatedBy: ".").first ?? url.lastPathComponent
            return BackupRecord(
                originalPath: originalName,
                backupPath: url.path,
                createdAt: values.creationDate ?? .distantPast
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    public func restore(_ record: BackupRecord) throws {
        let backupURL = URL(fileURLWithPath: record.backupPath)
        let originalURL = URL(fileURLWithPath: record.originalPath)
        try fileManager.createDirectory(at: originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: originalURL.path) {
            try fileManager.removeItem(at: originalURL)
        }
        try fileManager.copyItem(at: backupURL, to: originalURL)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

private extension JSONEncoder {
    static var macEnvManager: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }
}

private extension JSONDecoder {
    static var macEnvManager: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
