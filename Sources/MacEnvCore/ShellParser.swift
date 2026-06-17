import Foundation

public struct ShellParser: Sendable {
    public init() {}

    public func parse(content: String, sourcePath: String) -> ShellParseResult {
        var definitions: [EnvVariable] = []
        var managedDefinitions: [EnvVariable] = []
        var importableDefinitions: [EnvVariable] = []
        var unmanagedLines: [UnmanagedShellLine] = []
        var pathDefinitions: [PathDefinition] = []
        var inManagedBlock = false
        var hasManagedBlock = false

        for (index, rawLine) in content.components(separatedBy: .newlines).enumerated() {
            let lineNumber = index + 1
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed == ShellSyntax.beginMarker {
                inManagedBlock = true
                hasManagedBlock = true
                continue
            }
            if trimmed == ShellSyntax.endMarker {
                inManagedBlock = false
                continue
            }
            guard !trimmed.isEmpty else { continue }

            let parseLine: String
            let isEnabled: Bool
            if inManagedBlock, trimmed.contains(ShellSyntax.disabledMarker) {
                let uncommented = trimmed.hasPrefix("#")
                    ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                    : trimmed
                parseLine = uncommented
                    .replacingOccurrences(of: ShellSyntax.disabledMarker, with: "")
                    .trimmingCharacters(in: .whitespaces)
                isEnabled = false
            } else {
                parseLine = trimmed
                isEnabled = !trimmed.hasPrefix("#")
            }

            guard !parseLine.hasPrefix("#") else { continue }

            guard let parsed = parseAssignment(parseLine) else {
                unmanagedLines.append(UnmanagedShellLine(lineNumber: lineNumber, content: rawLine, reason: "Unsupported shell syntax"))
                continue
            }

            if ShellSyntax.containsComplexShellExpression(parsed.rawValue) {
                unmanagedLines.append(UnmanagedShellLine(lineNumber: lineNumber, content: rawLine, reason: "Complex shell expression"))
                continue
            }

            if parsed.name == "PATH" {
                pathDefinitions.append(PathDefinition(
                    entries: pathEntries(from: parsed.value, sourcePath: sourcePath, lineNumber: lineNumber, rawLine: rawLine),
                    preservesExistingPath: parsed.value.split(separator: ":").contains("$PATH"),
                    sourcePath: sourcePath,
                    lineNumber: lineNumber,
                    rawLine: rawLine
                ))
                continue
            }

            let source: EnvVariableSource = inManagedBlock ? .managed : .dotfile(sourcePath)
            let variable = EnvVariable(
                name: parsed.name,
                value: parsed.value,
                isExported: parsed.isExported,
                isEnabled: isEnabled,
                source: source
            )

            definitions.append(variable)
            if inManagedBlock {
                managedDefinitions.append(variable)
            } else {
                importableDefinitions.append(variable)
            }
        }

        _ = hasManagedBlock
        return ShellParseResult(
            definitions: definitions,
            managedDefinitions: managedDefinitions,
            importableDefinitions: importableDefinitions,
            unmanagedLines: unmanagedLines,
            pathDefinitions: pathDefinitions
        )
    }

    private func parseAssignment(_ line: String) -> (isExported: Bool, name: String, rawValue: String, value: String)? {
        var remainder = line
        var isExported = false
        if remainder.hasPrefix("export ") {
            isExported = true
            remainder = String(remainder.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
        }

        guard let equalsIndex = remainder.firstIndex(of: "=") else { return nil }
        let name = String(remainder[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
        guard ShellSyntax.isValidVariableName(name) else { return nil }

        let rawValue = String(remainder[remainder.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
        let value = ShellSyntax.unquote(rawValue)
        return (isExported, name, rawValue, value)
    }

    private func pathEntries(from value: String, sourcePath: String, lineNumber: Int, rawLine: String) -> [PathEntry] {
        var seen: Set<String> = []
        return value
            .split(separator: ":", omittingEmptySubsequences: true)
            .map(String.init)
            .filter { $0 != "$PATH" && $0 != "${PATH}" }
            .map { entry in
                let duplicate = seen.contains(entry)
                seen.insert(entry)
                return PathEntry(
                    value: entry,
                    isEnabled: true,
                    isDuplicate: duplicate,
                    sourcePath: sourcePath,
                    lineNumber: lineNumber,
                    rawLine: rawLine
                )
            }
    }
}
