import Foundation

public struct KeychainSecretStore: Sendable {
    public var serviceName: String

    public init(serviceName: String = "Mac Env Manager") {
        self.serviceName = serviceName
    }

    public func savePlan(account: String, value: String) -> CommandPlan {
        CommandPlan(
            title: "保存 \(account) 到 Keychain",
            executable: "/usr/bin/security",
            arguments: ["add-generic-password", "-U", "-s", serviceName, "-a", account, "-w", value],
            previewExecutable: "security"
        )
    }

    public func readPlan(account: String) -> CommandPlan {
        CommandPlan(
            title: "读取 \(account)",
            executable: "/usr/bin/security",
            arguments: ["find-generic-password", "-s", serviceName, "-a", account, "-w"],
            previewExecutable: "security"
        )
    }

    public func deletePlan(account: String) -> CommandPlan {
        CommandPlan(
            title: "删除 \(account)",
            executable: "/usr/bin/security",
            arguments: ["delete-generic-password", "-s", serviceName, "-a", account],
            previewExecutable: "security"
        )
    }

    public func shellSnippet(account: String) -> String {
        "export \(account)=$(security find-generic-password -s \(ShellSyntax.shellSingleQuote(serviceName)) -a \(ShellSyntax.shellSingleQuote(account)) -w)"
    }
}

