import Foundation

public struct EnvironmentTemplateVariable: Identifiable, Hashable, Codable, Sendable {
    public var id: String { name }
    public var name: String
    public var value: String
    public var isExported: Bool

    public init(name: String, value: String, isExported: Bool = true) {
        self.name = name
        self.value = value
        self.isExported = isExported
    }
}

public struct EnvironmentTemplate: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var checkCommands: [CommandPlan]
    public var variables: [EnvironmentTemplateVariable]
    public var pathEntries: [String]
    public var installCommands: [CommandPlan]

    public init(
        id: String,
        title: String,
        summary: String,
        checkCommands: [CommandPlan] = [],
        variables: [EnvironmentTemplateVariable] = [],
        pathEntries: [String] = [],
        installCommands: [CommandPlan] = []
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.checkCommands = checkCommands
        self.variables = variables
        self.pathEntries = pathEntries
        self.installCommands = installCommands
    }
}

public struct EnvironmentTemplateCatalog: Sendable {
    public var templates: [EnvironmentTemplate]

    public init(templates: [EnvironmentTemplate]) {
        self.templates = templates
    }

    public static func defaultCatalog() -> EnvironmentTemplateCatalog {
        EnvironmentTemplateCatalog(templates: [
            homebrewTemplate(),
            nodeTemplate(),
            pythonTemplate(),
            javaTemplate(),
            androidTemplate(),
            goTemplate(),
            rustTemplate(),
            proxyTemplate()
        ])
    }

    public func preview(for template: EnvironmentTemplate) -> String {
        var lines: [String] = []
        lines.append("# \(template.title)")
        if !template.variables.isEmpty {
            lines.append("# 变量")
            lines.append(contentsOf: template.variables.map { variable in
                let prefix = variable.isExported ? "export " : ""
                return "\(prefix)\(variable.name)=\(ShellSyntax.shellSingleQuote(variable.value))"
            })
        }
        if !template.pathEntries.isEmpty {
            lines.append("# PATH")
            lines.append(contentsOf: template.pathEntries.map { "PATH += \($0)" })
        }
        if !template.installCommands.isEmpty {
            lines.append("# 一键安装命令")
            lines.append(contentsOf: template.installCommands.map(\.previewCommand))
        }
        return lines.joined(separator: "\n")
    }

    private static func check(_ command: String) -> CommandPlan {
        CommandPlan(title: "检测 \(command)", executable: "/bin/zsh", arguments: ["-lc", "command -v \(command)"], previewExecutable: "zsh")
    }

    private static func brewInstall(_ title: String, _ formula: String) -> CommandPlan {
        CommandPlan(title: title, executable: "/bin/zsh", arguments: ["-lc", "brew install \(formula)"], previewExecutable: "zsh")
    }

    private static func homebrewTemplate() -> EnvironmentTemplate {
        EnvironmentTemplate(
            id: "homebrew",
            title: "Homebrew",
            summary: "安装和配置 Homebrew 路径",
            checkCommands: [check("brew")],
            pathEntries: ["/opt/homebrew/bin", "/usr/local/bin"],
            installCommands: [
                CommandPlan(
                    title: "安装 Homebrew",
                    executable: "/bin/zsh",
                    arguments: ["-lc", #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#],
                    previewExecutable: "zsh"
                )
            ]
        )
    }

    private static func nodeTemplate() -> EnvironmentTemplate {
        EnvironmentTemplate(
            id: "node",
            title: "Node.js",
            summary: "安装 Node.js、npm，并启用 Corepack",
            checkCommands: [check("node"), check("npm"), check("corepack")],
            installCommands: [brewInstall("安装 Node.js", "node"), CommandPlan(title: "启用 Corepack", executable: "/bin/zsh", arguments: ["-lc", "corepack enable"], previewExecutable: "zsh")]
        )
    }

    private static func pythonTemplate() -> EnvironmentTemplate {
        EnvironmentTemplate(
            id: "python",
            title: "Python",
            summary: "安装 Python 3 和 pip",
            checkCommands: [check("python3"), check("pip3")],
            installCommands: [brewInstall("安装 Python", "python")]
        )
    }

    private static func javaTemplate() -> EnvironmentTemplate {
        EnvironmentTemplate(
            id: "java",
            title: "Java",
            summary: "安装 Temurin JDK 并设置 JAVA_HOME",
            checkCommands: [check("java")],
            variables: [EnvironmentTemplateVariable(name: "JAVA_HOME", value: "$(/usr/libexec/java_home)")],
            installCommands: [brewInstall("安装 Temurin JDK", "--cask temurin")]
        )
    }

    private static func androidTemplate() -> EnvironmentTemplate {
        EnvironmentTemplate(
            id: "android",
            title: "Android",
            summary: "配置 Android SDK 和 platform-tools",
            checkCommands: [check("adb")],
            variables: [EnvironmentTemplateVariable(name: "ANDROID_HOME", value: "$HOME/Library/Android/sdk")],
            pathEntries: ["$ANDROID_HOME/platform-tools", "$ANDROID_HOME/emulator", "$ANDROID_HOME/cmdline-tools/latest/bin"],
            installCommands: [brewInstall("安装 Android platform tools", "--cask android-platform-tools")]
        )
    }

    private static func goTemplate() -> EnvironmentTemplate {
        EnvironmentTemplate(
            id: "go",
            title: "Go",
            summary: "安装 Go 并设置 GOPATH",
            checkCommands: [check("go")],
            variables: [EnvironmentTemplateVariable(name: "GOPATH", value: "$HOME/go")],
            pathEntries: ["$GOPATH/bin"],
            installCommands: [brewInstall("安装 Go", "go")]
        )
    }

    private static func rustTemplate() -> EnvironmentTemplate {
        EnvironmentTemplate(
            id: "rust",
            title: "Rust",
            summary: "安装 rustup、rustc 和 cargo",
            checkCommands: [check("rustc"), check("cargo")],
            pathEntries: ["$HOME/.cargo/bin"],
            installCommands: [CommandPlan(title: "安装 Rust", executable: "/bin/zsh", arguments: ["-lc", "curl https://sh.rustup.rs -sSf | sh"], previewExecutable: "zsh")]
        )
    }

    private static func proxyTemplate() -> EnvironmentTemplate {
        EnvironmentTemplate(
            id: "proxy",
            title: "代理变量",
            summary: "配置 http_proxy、https_proxy 和 all_proxy",
            variables: [
                EnvironmentTemplateVariable(name: "http_proxy", value: "http://127.0.0.1:7897"),
                EnvironmentTemplateVariable(name: "https_proxy", value: "http://127.0.0.1:7897"),
                EnvironmentTemplateVariable(name: "all_proxy", value: "socks5://127.0.0.1:7897")
            ]
        )
    }
}

