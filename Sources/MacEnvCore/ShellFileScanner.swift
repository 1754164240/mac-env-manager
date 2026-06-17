import Foundation

public struct ShellFileScanner {
    public static let managedRelativePath = ".mac-env-manager/env.sh"
    public static let supportedDotfiles = [".zshrc", ".zprofile", ".bash_profile", ".bashrc", ".profile"]

    public var homeDirectory: URL
    public var fileManager: FileManager

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser, fileManager: FileManager = .default) {
        self.homeDirectory = homeDirectory
        self.fileManager = fileManager
    }

    public func scan() throws -> EnvironmentSnapshot {
        let parser = ShellParser()
        var variables: [EnvVariable] = []
        var pathEntries: [PathEntry] = []
        var sources: [ShellSource] = []
        var unmanagedLines: [UnmanagedShellLine] = []

        for relativePath in [Self.managedRelativePath] + Self.supportedDotfiles {
            let fileURL = homeDirectory.appendingPathComponent(relativePath)
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let result = parser.parse(content: content, sourcePath: fileURL.path)

            let sourceVariables = relativePath == Self.managedRelativePath
                ? result.managedDefinitions + result.importableDefinitions
                : result.managedDefinitions + result.importableDefinitions
            variables.append(contentsOf: sourceVariables)
            for pathDefinition in result.pathDefinitions where !pathDefinition.entries.isEmpty {
                pathEntries.append(contentsOf: markPathExistence(pathDefinition.entries))
            }
            unmanagedLines.append(contentsOf: result.unmanagedLines)
            sources.append(
                ShellSource(
                    path: fileURL.path,
                    isEnabled: true,
                    hasManagedBlock: content.contains(ShellSyntax.beginMarker),
                    importableCount: result.importableDefinitions.count,
                    unmanagedCount: result.unmanagedLines.count
                )
            )
        }

        return EnvironmentSnapshot(
            variables: variables,
            pathEntries: markDuplicatePathEntries(pathEntries),
            sources: sources,
            unmanagedLines: unmanagedLines
        )
    }

    private func markDuplicatePathEntries(_ entries: [PathEntry]) -> [PathEntry] {
        var seen: Set<String> = []
        return entries.map { entry in
            var updated = entry
            updated.isDuplicate = seen.contains(entry.value)
            if updated.isDuplicate {
                updated.isEnabled = false
            }
            seen.insert(entry.value)
            return updated
        }
    }

    private func markPathExistence(_ entries: [PathEntry]) -> [PathEntry] {
        entries.map { entry in
            var updated = entry
            updated.existsOnDisk = pathEntryExists(entry.value)
            return updated
        }
    }

    private func pathEntryExists(_ value: String) -> Bool? {
        guard !value.isEmpty else { return false }
        if value.hasPrefix("$HOME/") {
            let relative = String(value.dropFirst("$HOME/".count))
            return fileManager.fileExists(atPath: homeDirectory.appendingPathComponent(relative).path)
        }
        if value.hasPrefix("~") {
            let relative = String(value.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return fileManager.fileExists(atPath: homeDirectory.appendingPathComponent(relative).path)
        }
        if value.hasPrefix("$") {
            return nil
        }
        return fileManager.fileExists(atPath: value)
    }
}
