import Foundation

public enum ShellSyntax {
    public static let beginMarker = "# >>> Mac Env Manager"
    public static let endMarker = "# <<< Mac Env Manager"
    public static let disabledMarker = "# mac-env-disabled"

    public static func isValidVariableName(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first else { return false }
        guard CharacterSet(charactersIn: "_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz").contains(first) else {
            return false
        }
        let allowed = CharacterSet(charactersIn: "_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return name.unicodeScalars.dropFirst().allSatisfy { allowed.contains($0) }
    }

    public static func shellSingleQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    static func stripInlineComment(_ value: String) -> String {
        var inSingleQuote = false
        var inDoubleQuote = false
        var result = ""
        var previous: Character?

        for character in value {
            if character == "'", !inDoubleQuote {
                inSingleQuote.toggle()
            } else if character == "\"", !inSingleQuote, previous != "\\" {
                inDoubleQuote.toggle()
            }

            if character == "#", !inSingleQuote, !inDoubleQuote {
                break
            }

            result.append(character)
            previous = character
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    static func unquote(_ rawValue: String) -> String {
        let trimmed = stripInlineComment(rawValue)
        guard trimmed.count >= 2 else { return trimmed }
        let first = trimmed.first
        let last = trimmed.last
        if (first == "'" && last == "'") || (first == "\"" && last == "\"") {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    static func containsComplexShellExpression(_ value: String) -> Bool {
        value.contains("$(") || value.contains("`") || value.contains("${")
    }
}
