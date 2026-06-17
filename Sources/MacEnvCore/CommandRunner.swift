import Foundation

public struct CommandPlan: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var title: String
    public var executable: String
    public var arguments: [String]
    public var previewExecutable: String?

    public init(
        id: UUID = UUID(),
        title: String,
        executable: String,
        arguments: [String] = [],
        previewExecutable: String? = nil
    ) {
        self.id = id
        self.title = title
        self.executable = executable
        self.arguments = arguments
        self.previewExecutable = previewExecutable
    }

    public var previewCommand: String {
        ([previewExecutable ?? executable] + arguments)
            .map(CommandLineQuoter.quote)
            .joined(separator: " ")
    }
}

public struct CommandResult: Hashable, Codable, Sendable {
    public var plan: CommandPlan
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32
    public var startedAt: Date
    public var finishedAt: Date

    public init(
        plan: CommandPlan,
        stdout: String,
        stderr: String,
        exitCode: Int32,
        startedAt: Date,
        finishedAt: Date
    ) {
        self.plan = plan
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public protocol CommandRunning: Sendable {
    func run(_ plan: CommandPlan) throws -> CommandResult
}

public struct ShellCommandRunner: CommandRunning {
    public init() {}

    public func run(_ plan: CommandPlan) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: plan.executable)
        process.arguments = plan.arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let startedAt = Date()
        try process.run()
        process.waitUntilExit()
        let finishedAt = Date()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return CommandResult(
            plan: plan,
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }
}

public enum CommandLineQuoter {
    public static func quote(_ value: String) -> String {
        guard !value.isEmpty else { return "''" }
        let safeCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_/@%+=,.-")
        if value.unicodeScalars.allSatisfy({ safeCharacters.contains($0) }) {
            return value
        }
        return ShellSyntax.shellSingleQuote(value)
    }
}
