import Foundation

public struct GUIEnvironmentVariable: Identifiable, Hashable, Codable, Sendable {
    public var id: String { name }
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

public struct GUIEnvironmentService: Sendable {
    public init() {}

    public func getPlan(name: String) -> CommandPlan {
        CommandPlan(
            title: "读取 GUI 环境变量 \(name)",
            executable: "/bin/launchctl",
            arguments: ["getenv", name],
            previewExecutable: "launchctl"
        )
    }

    public func setPlan(name: String, value: String) -> CommandPlan {
        CommandPlan(
            title: "设置 GUI 环境变量 \(name)",
            executable: "/bin/launchctl",
            arguments: ["setenv", name, value],
            previewExecutable: "launchctl"
        )
    }

    public func unsetPlan(name: String) -> CommandPlan {
        CommandPlan(
            title: "删除 GUI 环境变量 \(name)",
            executable: "/bin/launchctl",
            arguments: ["unsetenv", name],
            previewExecutable: "launchctl"
        )
    }

    public func parseGetenvResult(_ result: CommandResult) -> String? {
        guard result.exitCode == 0 else { return nil }
        let value = result.stdout.trimmingCharacters(in: .newlines)
        return value.isEmpty ? nil : value
    }
}

