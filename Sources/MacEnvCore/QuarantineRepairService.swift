import Foundation

public enum QuarantineRepairError: Error, LocalizedError, Equatable, Sendable {
    case notApplicationBundle(String)
    case appleScriptFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notApplicationBundle(let path):
            "请选择 .app 应用程序：\(path)"
        case .appleScriptFailed(let message):
            "修复失败：\(message)"
        }
    }
}

public struct QuarantineRepairPlan: Hashable, Sendable {
    public var appPath: String
    public var displayName: String
    public var terminalCommand: String
    public var appleScript: String

    public init(appPath: String, displayName: String, terminalCommand: String, appleScript: String) {
        self.appPath = appPath
        self.displayName = displayName
        self.terminalCommand = terminalCommand
        self.appleScript = appleScript
    }
}

public struct QuarantineRepairService: Sendable {
    public init() {}

    public func planRepair(for appURL: URL) throws -> QuarantineRepairPlan {
        let path = appURL.path
        guard appURL.pathExtension == "app" else {
            throw QuarantineRepairError.notApplicationBundle(path)
        }

        let quotedPath = shellSingleQuote(path)
        let shellCommand = "xattr -rd com.apple.quarantine \(quotedPath)"
        return QuarantineRepairPlan(
            appPath: path,
            displayName: appURL.lastPathComponent,
            terminalCommand: "sudo \(shellCommand)",
            appleScript: "do shell script \"\(escapeForAppleScript(shellCommand))\" with administrator privileges"
        )
    }

    public func repair(for appURL: URL) throws -> QuarantineRepairPlan {
        let plan = try planRepair(for: appURL)
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", plan.appleScript]
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw QuarantineRepairError.appleScriptFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return plan
    }

    private func shellSingleQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func escapeForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
