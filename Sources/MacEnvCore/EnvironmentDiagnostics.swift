import Foundation

public enum DiagnosticSeverity: String, Hashable, Codable, Sendable {
    case info
    case warning
    case error
}

public struct EnvironmentDiagnostic: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var severity: DiagnosticSeverity
    public var title: String
    public var message: String
    public var actionTitle: String?

    public init(
        id: UUID = UUID(),
        severity: DiagnosticSeverity,
        title: String,
        message: String,
        actionTitle: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
    }
}

public struct ToolCheckResult: Identifiable, Hashable, Codable, Sendable {
    public var id: String { command }
    public var command: String
    public var isAvailable: Bool
    public var resolvedPath: String?

    public init(command: String, isAvailable: Bool, resolvedPath: String? = nil) {
        self.command = command
        self.isAvailable = isAvailable
        self.resolvedPath = resolvedPath
    }
}

public struct EnvironmentDiagnosticsService: Sendable {
    public init() {}

    public func diagnose(
        snapshot: EnvironmentSnapshot,
        guiVariables: [GUIEnvironmentVariable],
        toolChecks: [ToolCheckResult],
        projectSnapshot: ProjectEnvSnapshot? = nil
    ) -> [EnvironmentDiagnostic] {
        var diagnostics: [EnvironmentDiagnostic] = []

        for entry in snapshot.pathEntries where entry.existsOnDisk == false {
            diagnostics.append(EnvironmentDiagnostic(
                severity: .warning,
                title: "PATH 不存在：\(entry.value)",
                message: "这个路径当前不存在，保留后可能让 PATH 变长且难以排查。",
                actionTitle: "查看 PATH"
            ))
        }

        for entry in snapshot.pathEntries where entry.isDuplicate {
            diagnostics.append(EnvironmentDiagnostic(
                severity: .info,
                title: "PATH 重复：\(entry.value)",
                message: "重复 PATH 通常没有必要，建议只保留第一次出现的路径。",
                actionTitle: "清理重复项"
            ))
        }

        let variableNames = Set(snapshot.variables.filter(\.isEnabled).map { $0.name })
        let proxyNames = Set(["http_proxy", "https_proxy", "all_proxy"])
        let presentProxyNames = proxyNames.intersection(variableNames)
        if !presentProxyNames.isEmpty, presentProxyNames.count < proxyNames.count {
            let missing = proxyNames.subtracting(presentProxyNames).sorted().joined(separator: ", ")
            diagnostics.append(EnvironmentDiagnostic(
                severity: .warning,
                title: "代理变量不完整",
                message: "已设置部分代理变量，但缺少 \(missing)。",
                actionTitle: "打开代理向导"
            ))
        }

        for variable in snapshot.variables where variable.isEnabled && variable.isLikelySensitive {
            diagnostics.append(EnvironmentDiagnostic(
                severity: .info,
                title: "疑似敏感变量：\(variable.name)",
                message: "这个变量名看起来像密钥。可以保留明文，也可以迁移到 Keychain。",
                actionTitle: "迁移到 Keychain"
            ))
        }

        let shellVariables = Dictionary(uniqueKeysWithValues: snapshot.variables.filter(\.isEnabled).map { ($0.name, $0.value) })
        for guiVariable in guiVariables {
            if let shellValue = shellVariables[guiVariable.name], shellValue != guiVariable.value {
                diagnostics.append(EnvironmentDiagnostic(
                    severity: .warning,
                    title: "GUI 环境不一致：\(guiVariable.name)",
                    message: "shell 中是 \(shellValue)，GUI 环境中是 \(guiVariable.value)。",
                    actionTitle: "同步 GUI 环境"
                ))
            }
        }

        for check in toolChecks where !check.isAvailable {
            diagnostics.append(EnvironmentDiagnostic(
                severity: .warning,
                title: "缺少开发工具：\(check.command)",
                message: "当前 PATH 中找不到 \(check.command)。可以通过环境向导安装或修复 PATH。",
                actionTitle: "打开向导"
            ))
        }

        if let projectSnapshot {
            for variable in projectSnapshot.variables where variable.isDuplicate {
                diagnostics.append(EnvironmentDiagnostic(
                    severity: .warning,
                    title: "项目变量重复：\(variable.key)",
                    message: "\(variable.key) 在 \(variable.fileName) 中重复定义，运行时可能覆盖前面的值。",
                    actionTitle: "查看项目"
                ))
            }
            for variable in projectSnapshot.variables where variable.value.isEmpty {
                diagnostics.append(EnvironmentDiagnostic(
                    severity: .info,
                    title: "项目变量为空：\(variable.key)",
                    message: "\(variable.key) 在 \(variable.fileName) 中没有值，确认这是预期行为。",
                    actionTitle: "编辑项目变量"
                ))
            }
        }

        return diagnostics
    }
}

public struct ToolCheckService: Sendable {
    public static let defaultCommands = ["brew", "node", "python3", "java", "go", "rustc", "adb"]

    private let runner: any CommandRunning

    public init(runner: any CommandRunning = ShellCommandRunner()) {
        self.runner = runner
    }

    public func check(commands: [String] = Self.defaultCommands) -> [ToolCheckResult] {
        commands.map { command in
            let plan = CommandPlan(
                title: "检测 \(command)",
                executable: "/bin/zsh",
                arguments: ["-lc", "command -v \(command)"],
                previewExecutable: "zsh"
            )
            do {
                let result = try runner.run(plan)
                let resolvedPath = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                return ToolCheckResult(
                    command: command,
                    isAvailable: result.exitCode == 0 && !resolvedPath.isEmpty,
                    resolvedPath: resolvedPath.isEmpty ? nil : resolvedPath
                )
            } catch {
                return ToolCheckResult(command: command, isAvailable: false)
            }
        }
    }
}
