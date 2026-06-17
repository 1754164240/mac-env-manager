import Foundation

public struct ProjectEnvFile: Identifiable, Hashable, Codable, Sendable {
    public var id: String { path }
    public var name: String
    public var path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

public struct ProjectEnvVariable: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var key: String
    public var value: String
    public var fileName: String
    public var filePath: String
    public var lineNumber: Int
    public var isDuplicate: Bool
    public var isCommented: Bool

    public init(
        id: UUID = UUID(),
        key: String,
        value: String,
        fileName: String,
        filePath: String,
        lineNumber: Int,
        isDuplicate: Bool = false,
        isCommented: Bool = false
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.fileName = fileName
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.isDuplicate = isDuplicate
        self.isCommented = isCommented
    }
}

public struct ProjectEnvSnapshot: Hashable, Codable, Sendable {
    public var projectDirectory: String
    public var files: [ProjectEnvFile]
    public var variables: [ProjectEnvVariable]

    public init(projectDirectory: String, files: [ProjectEnvFile] = [], variables: [ProjectEnvVariable] = []) {
        self.projectDirectory = projectDirectory
        self.files = files
        self.variables = variables
    }
}

public struct ProjectEnvScanner {
    public static let supportedFileNames = [".env", ".env.local", ".env.development", ".env.production", ".envrc"]

    public var projectDirectory: URL
    public var fileManager: FileManager

    public init(projectDirectory: URL, fileManager: FileManager = .default) {
        self.projectDirectory = projectDirectory
        self.fileManager = fileManager
    }

    public func scan() throws -> ProjectEnvSnapshot {
        var files: [ProjectEnvFile] = []
        var variables: [ProjectEnvVariable] = []
        var seenKeys: Set<String> = []

        for fileName in Self.supportedFileNames {
            let fileURL = projectDirectory.appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }
            files.append(ProjectEnvFile(name: fileName, path: fileURL.path))
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            for parsed in ProjectEnvParser.parse(content: content, fileName: fileName, filePath: fileURL.path) {
                var variable = parsed
                variable.isDuplicate = seenKeys.contains(variable.key)
                seenKeys.insert(variable.key)
                variables.append(variable)
            }
        }

        return ProjectEnvSnapshot(projectDirectory: projectDirectory.path, files: files, variables: variables)
    }
}

public struct ProjectEnvWriter: Sendable {
    public var projectDirectory: URL

    public init(projectDirectory: URL) {
        self.projectDirectory = projectDirectory
    }

    public var backupsDirectory: URL {
        projectDirectory
            .appendingPathComponent(".mac-env-manager", isDirectory: true)
            .appendingPathComponent("backups", isDirectory: true)
    }

    public func direnvContent(forEnvFile fileName: String) -> String {
        "dotenv \(fileName)\n"
    }

    public func planWrite(fileName: String, variables: [ProjectEnvVariable]) throws -> FileChange {
        let destination = projectDirectory.appendingPathComponent(fileName)
        let original = FileManager.default.fileExists(atPath: destination.path)
            ? try String(contentsOf: destination, encoding: .utf8)
            : ""
        let updated = variables
            .sorted { ($0.fileName, $0.lineNumber, $0.key) < ($1.fileName, $1.lineNumber, $1.key) }
            .map { "\($0.key)=\(ShellSyntax.shellSingleQuote($0.value))" }
            .joined(separator: "\n") + "\n"
        return FileChange(
            path: destination.path,
            original: original,
            updated: updated,
            diff: DiffBuilder.diff(path: destination.path, original: original, updated: updated)
        )
    }
}

enum ProjectEnvParser {
    static func parse(content: String, fileName: String, filePath: String) -> [ProjectEnvVariable] {
        content.components(separatedBy: .newlines).enumerated().compactMap { index, rawLine in
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
            let line = trimmed.hasPrefix("export ")
                ? String(trimmed.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
                : trimmed
            guard let equalsIndex = line.firstIndex(of: "=") else { return nil }
            let key = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
            guard ShellSyntax.isValidVariableName(key) else { return nil }
            let rawValue = String(line[line.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
            return ProjectEnvVariable(
                key: key,
                value: ShellSyntax.unquote(rawValue),
                fileName: fileName,
                filePath: filePath,
                lineNumber: index + 1
            )
        }
    }
}
