import Foundation
import Observation

@MainActor
@Observable
public final class ProEnvironmentViewModel {
    public var diagnostics: [EnvironmentDiagnostic]
    public var guiVariableName: String
    public var guiVariableValue: String
    public var guiVariables: [GUIEnvironmentVariable]
    public var pendingGUIPlan: CommandPlan?
    public var guiCommandResults: [CommandResult]
    public var projectDirectory: URL?
    public var projectSnapshot: ProjectEnvSnapshot?
    public var selectedProjectVariableID: ProjectEnvVariable.ID?
    public var selectedProjectEnvFileName: String
    public var projectVariableKey: String
    public var projectVariableValue: String
    public var pendingProjectChange: FileChange?
    public var projectApplyResult: ApplyResult?
    public var secretName: String
    public var secretValue: String
    public var pendingKeychainPlan: CommandPlan?
    public var keychainCommandResults: [CommandResult]
    public var selectedTemplateID: EnvironmentTemplate.ID?
    public var templateCommandResults: [CommandResult]
    public var errorMessage: String?

    public let catalog: EnvironmentTemplateCatalog
    private let guiService: GUIEnvironmentService
    private let keychainStore: KeychainSecretStore
    private let diagnosticsService: EnvironmentDiagnosticsService
    private let toolCheckService: ToolCheckService
    private let commandRunner: any CommandRunning

    public init(
        catalog: EnvironmentTemplateCatalog = .defaultCatalog(),
        guiService: GUIEnvironmentService = GUIEnvironmentService(),
        keychainStore: KeychainSecretStore = KeychainSecretStore(),
        diagnosticsService: EnvironmentDiagnosticsService = EnvironmentDiagnosticsService(),
        toolCheckService: ToolCheckService = ToolCheckService(),
        commandRunner: any CommandRunning = ShellCommandRunner()
    ) {
        self.catalog = catalog
        self.guiService = guiService
        self.keychainStore = keychainStore
        self.diagnosticsService = diagnosticsService
        self.toolCheckService = toolCheckService
        self.commandRunner = commandRunner
        self.diagnostics = []
        self.guiVariableName = ""
        self.guiVariableValue = ""
        self.guiVariables = []
        self.guiCommandResults = []
        self.selectedProjectEnvFileName = ".env"
        self.projectVariableKey = ""
        self.projectVariableValue = ""
        self.secretName = ""
        self.secretValue = ""
        self.keychainCommandResults = []
        self.templateCommandResults = []
        self.selectedTemplateID = catalog.templates.first?.id
    }

    public var selectedTemplate: EnvironmentTemplate? {
        guard let selectedTemplateID else { return catalog.templates.first }
        return catalog.templates.first { $0.id == selectedTemplateID }
    }

    public var templatePreview: String {
        guard let selectedTemplate else { return "" }
        return catalog.preview(for: selectedTemplate)
    }

    public var pendingGUICommandPreview: String {
        pendingGUIPlan?.previewCommand ?? ""
    }

    public var keychainShellSnippet: String {
        guard ShellSyntax.isValidVariableName(secretName) else { return "" }
        return keychainStore.shellSnippet(account: secretName)
    }

    public func selectTemplate(id: EnvironmentTemplate.ID) {
        selectedTemplateID = id
    }

    public func applySelectedTemplate(to snapshot: inout EnvironmentSnapshot) {
        guard let selectedTemplate else { return }
        for templateVariable in selectedTemplate.variables {
            if let index = snapshot.variables.firstIndex(where: { $0.name == templateVariable.name }) {
                snapshot.variables[index].value = templateVariable.value
                snapshot.variables[index].isExported = templateVariable.isExported
                snapshot.variables[index].isEnabled = true
            } else {
                snapshot.variables.append(
                    EnvVariable(
                        name: templateVariable.name,
                        value: templateVariable.value,
                        isExported: templateVariable.isExported,
                        isEnabled: true,
                        source: .managed
                    )
                )
            }
        }

        let existingPaths = Set(snapshot.pathEntries.map(\.value))
        for pathEntry in selectedTemplate.pathEntries where !existingPaths.contains(pathEntry) {
            snapshot.pathEntries.append(PathEntry(value: pathEntry, isEnabled: true))
        }
    }

    public func loadDiagnostics(snapshot: EnvironmentSnapshot, guiVariables: [GUIEnvironmentVariable] = [], toolChecks: [ToolCheckResult] = []) {
        diagnostics = diagnosticsService.diagnose(
            snapshot: snapshot,
            guiVariables: guiVariables,
            toolChecks: toolChecks,
            projectSnapshot: projectSnapshot
        )
    }

    public func refreshDiagnostics(snapshot: EnvironmentSnapshot, guiVariables: [GUIEnvironmentVariable] = []) {
        let checks = toolCheckService.check()
        diagnostics = diagnosticsService.diagnose(
            snapshot: snapshot,
            guiVariables: guiVariables,
            toolChecks: checks,
            projectSnapshot: projectSnapshot
        )
    }

    public func buildGUIGetPlan() {
        guard ShellSyntax.isValidVariableName(guiVariableName) else {
            errorMessage = "GUI 环境变量名无效：\(guiVariableName)"
            pendingGUIPlan = nil
            return
        }
        pendingGUIPlan = guiService.getPlan(name: guiVariableName)
    }

    public func buildGUISetPlan() {
        guard ShellSyntax.isValidVariableName(guiVariableName) else {
            errorMessage = "GUI 环境变量名无效：\(guiVariableName)"
            pendingGUIPlan = nil
            return
        }
        pendingGUIPlan = guiService.setPlan(name: guiVariableName, value: guiVariableValue)
    }

    public func buildGUIUnsetPlan() {
        guard ShellSyntax.isValidVariableName(guiVariableName) else {
            errorMessage = "GUI 环境变量名无效：\(guiVariableName)"
            pendingGUIPlan = nil
            return
        }
        pendingGUIPlan = guiService.unsetPlan(name: guiVariableName)
    }

    public func runPendingGUIPlan() {
        guard let pendingGUIPlan else { return }
        do {
            let result = try commandRunner.run(pendingGUIPlan)
            if pendingGUIPlan.arguments.first == "getenv", let value = guiService.parseGetenvResult(result) {
                guiVariableValue = value
                upsertGUIVariable(name: guiVariableName, value: value)
            } else if pendingGUIPlan.arguments.first == "setenv", result.exitCode == 0 {
                upsertGUIVariable(name: guiVariableName, value: guiVariableValue)
            } else if pendingGUIPlan.arguments.first == "unsetenv", result.exitCode == 0 {
                guiVariables.removeAll { $0.name == guiVariableName }
            }
            guiCommandResults.insert(result, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func scanProject(at url: URL) throws {
        projectDirectory = url
        projectSnapshot = try ProjectEnvScanner(projectDirectory: url).scan()
        if let variable = projectSnapshot?.variables.first {
            selectedProjectVariableID = variable.id
            selectedProjectEnvFileName = variable.fileName
            projectVariableKey = variable.key
            projectVariableValue = variable.value
        }
    }

    public func selectProjectVariable(id: ProjectEnvVariable.ID?) {
        selectedProjectVariableID = id
        guard let id, let variable = projectSnapshot?.variables.first(where: { $0.id == id }) else { return }
        selectedProjectEnvFileName = variable.fileName
        projectVariableKey = variable.key
        projectVariableValue = variable.value
    }

    public func planProjectEnvWrite(fileName: String? = nil) throws {
        guard let projectDirectory else { return }
        let targetFileName = fileName ?? selectedProjectEnvFileName
        guard ShellSyntax.isValidVariableName(projectVariableKey) else {
            errorMessage = "项目变量名无效：\(projectVariableKey)"
            pendingProjectChange = nil
            return
        }

        var variables = projectSnapshot?.variables.filter { $0.fileName == targetFileName } ?? []
        if let index = variables.firstIndex(where: { $0.key == projectVariableKey }) {
            variables[index].value = projectVariableValue
        } else {
            let filePath = projectDirectory.appendingPathComponent(targetFileName).path
            variables.append(ProjectEnvVariable(
                key: projectVariableKey,
                value: projectVariableValue,
                fileName: targetFileName,
                filePath: filePath,
                lineNumber: (variables.map(\.lineNumber).max() ?? 0) + 1
            ))
        }

        pendingProjectChange = try ProjectEnvWriter(projectDirectory: projectDirectory)
            .planWrite(fileName: targetFileName, variables: variables)
    }

    public func applyProjectEnvWrite() throws {
        guard let projectDirectory, let pendingProjectChange else { return }
        let writer = ShellFileWriter(backupStore: BackupStore(rootDirectory: projectDirectory))
        projectApplyResult = try writer.apply(changeSet: ChangeSet(changes: [pendingProjectChange]))
        try scanProject(at: projectDirectory)
    }

    public func buildKeychainSavePlan() {
        guard ShellSyntax.isValidVariableName(secretName) else {
            errorMessage = "密钥变量名无效：\(secretName)"
            pendingKeychainPlan = nil
            return
        }
        pendingKeychainPlan = keychainStore.savePlan(account: secretName, value: secretValue)
    }

    public func buildKeychainReadPlan() {
        guard ShellSyntax.isValidVariableName(secretName) else {
            errorMessage = "密钥变量名无效：\(secretName)"
            pendingKeychainPlan = nil
            return
        }
        pendingKeychainPlan = keychainStore.readPlan(account: secretName)
    }

    public func buildKeychainDeletePlan() {
        guard ShellSyntax.isValidVariableName(secretName) else {
            errorMessage = "密钥变量名无效：\(secretName)"
            pendingKeychainPlan = nil
            return
        }
        pendingKeychainPlan = keychainStore.deletePlan(account: secretName)
    }

    public func runPendingKeychainPlan() {
        guard let pendingKeychainPlan else { return }
        do {
            keychainCommandResults.insert(try commandRunner.run(pendingKeychainPlan), at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func runInstallCommand(_ plan: CommandPlan) {
        do {
            templateCommandResults.insert(try commandRunner.run(plan), at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsertGUIVariable(name: String, value: String) {
        if let index = guiVariables.firstIndex(where: { $0.name == name }) {
            guiVariables[index].value = value
        } else {
            guiVariables.append(GUIEnvironmentVariable(name: name, value: value))
        }
    }
}
