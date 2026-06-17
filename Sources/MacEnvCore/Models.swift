import Foundation

public enum EnvVariableSource: Hashable, Codable, Sendable {
    case managed
    case dotfile(String)
    case unmanaged(String)
}

public struct EnvVariable: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var value: String
    public var isExported: Bool
    public var isEnabled: Bool
    public var source: EnvVariableSource
    public var isTakenOver: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        value: String,
        isExported: Bool = true,
        isEnabled: Bool = true,
        source: EnvVariableSource,
        isTakenOver: Bool = false
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.isExported = isExported
        self.isEnabled = isEnabled
        self.source = source
        self.isTakenOver = isTakenOver
    }
}

public struct PathEntry: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var value: String
    public var isEnabled: Bool
    public var isDuplicate: Bool
    public var existsOnDisk: Bool?
    public var sourcePath: String?
    public var lineNumber: Int?
    public var rawLine: String?

    public init(
        id: UUID = UUID(),
        value: String,
        isEnabled: Bool = true,
        isDuplicate: Bool = false,
        existsOnDisk: Bool? = nil,
        sourcePath: String? = nil,
        lineNumber: Int? = nil,
        rawLine: String? = nil
    ) {
        self.id = id
        self.value = value
        self.isEnabled = isEnabled
        self.isDuplicate = isDuplicate
        self.existsOnDisk = existsOnDisk
        self.sourcePath = sourcePath
        self.lineNumber = lineNumber
        self.rawLine = rawLine
    }
}

public struct PathDefinition: Hashable, Codable, Sendable {
    public var entries: [PathEntry]
    public var preservesExistingPath: Bool
    public var sourcePath: String
    public var lineNumber: Int
    public var rawLine: String

    public init(
        entries: [PathEntry],
        preservesExistingPath: Bool,
        sourcePath: String,
        lineNumber: Int = 0,
        rawLine: String = ""
    ) {
        self.entries = entries
        self.preservesExistingPath = preservesExistingPath
        self.sourcePath = sourcePath
        self.lineNumber = lineNumber
        self.rawLine = rawLine
    }
}

public struct UnmanagedShellLine: Hashable, Codable, Sendable {
    public var lineNumber: Int
    public var content: String
    public var reason: String

    public init(lineNumber: Int, content: String, reason: String) {
        self.lineNumber = lineNumber
        self.content = content
        self.reason = reason
    }
}

public struct ShellParseResult: Hashable, Codable, Sendable {
    public var definitions: [EnvVariable]
    public var managedDefinitions: [EnvVariable]
    public var importableDefinitions: [EnvVariable]
    public var unmanagedLines: [UnmanagedShellLine]
    public var pathDefinitions: [PathDefinition]

    public var pathDefinition: PathDefinition? {
        pathDefinitions.last
    }

    public init(
        definitions: [EnvVariable] = [],
        managedDefinitions: [EnvVariable] = [],
        importableDefinitions: [EnvVariable] = [],
        unmanagedLines: [UnmanagedShellLine] = [],
        pathDefinitions: [PathDefinition] = [],
        pathDefinition: PathDefinition? = nil
    ) {
        self.definitions = definitions
        self.managedDefinitions = managedDefinitions
        self.importableDefinitions = importableDefinitions
        self.unmanagedLines = unmanagedLines
        self.pathDefinitions = pathDefinitions.isEmpty ? pathDefinition.map { [$0] } ?? [] : pathDefinitions
    }
}

public struct ShellSource: Identifiable, Hashable, Codable, Sendable {
    public var id: String { path }
    public var path: String
    public var isEnabled: Bool
    public var hasManagedBlock: Bool
    public var importableCount: Int
    public var unmanagedCount: Int

    public init(
        path: String,
        isEnabled: Bool = true,
        hasManagedBlock: Bool = false,
        importableCount: Int = 0,
        unmanagedCount: Int = 0
    ) {
        self.path = path
        self.isEnabled = isEnabled
        self.hasManagedBlock = hasManagedBlock
        self.importableCount = importableCount
        self.unmanagedCount = unmanagedCount
    }
}

public struct EnvironmentSnapshot: Hashable, Codable, Sendable {
    public var variables: [EnvVariable]
    public var pathEntries: [PathEntry]
    public var sources: [ShellSource]
    public var unmanagedLines: [UnmanagedShellLine]

    public init(
        variables: [EnvVariable] = [],
        pathEntries: [PathEntry] = [],
        sources: [ShellSource] = [],
        unmanagedLines: [UnmanagedShellLine] = []
    ) {
        self.variables = variables
        self.pathEntries = pathEntries
        self.sources = sources
        self.unmanagedLines = unmanagedLines
    }
}

public struct FileChange: Identifiable, Hashable, Codable, Sendable {
    public var id: String { path }
    public var path: String
    public var original: String
    public var updated: String
    public var diff: String

    public init(path: String, original: String, updated: String, diff: String) {
        self.path = path
        self.original = original
        self.updated = updated
        self.diff = diff
    }
}

public struct ChangeSet: Hashable, Codable, Sendable {
    public var changes: [FileChange]
    public var warnings: [String]
    public var sourceCommands: [String]

    public init(changes: [FileChange] = [], warnings: [String] = [], sourceCommands: [String] = []) {
        self.changes = changes
        self.warnings = warnings
        self.sourceCommands = sourceCommands
    }

    public var isEmpty: Bool { changes.allSatisfy { $0.original == $0.updated } }
    public var combinedDiff: String { changes.map(\.diff).joined(separator: "\n") }
}

public struct BackupRecord: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var originalPath: String
    public var backupPath: String
    public var createdAt: Date

    public init(id: UUID = UUID(), originalPath: String, backupPath: String, createdAt: Date = Date()) {
        self.id = id
        self.originalPath = originalPath
        self.backupPath = backupPath
        self.createdAt = createdAt
    }
}

public struct ApplyResult: Hashable, Codable, Sendable {
    public var backups: [BackupRecord]
    public var sourceCommands: [String]

    public init(backups: [BackupRecord], sourceCommands: [String]) {
        self.backups = backups
        self.sourceCommands = sourceCommands
    }
}
