import Foundation
import Observation

@MainActor
@Observable
public final class EnvironmentViewModel {
    public var snapshot: EnvironmentSnapshot
    public var selectedSection: AppSection
    public var selectedVariableID: EnvVariable.ID?
    public var selectedPathEntryID: PathEntry.ID?
    public var selectedSourcePath: ShellSource.ID?
    public var searchText: String
    public var pendingChangeSet: ChangeSet?
    public var lastApplyResult: ApplyResult?
    public var backupRecords: [BackupRecord]
    public var selectedBackupID: BackupRecord.ID?
    public var errorMessage: String?
    public var showsSensitiveValues: Bool
    public var isLoading: Bool
    public var selectedRepairPlan: QuarantineRepairPlan?
    public var repairMessage: String?

    public let homeDirectory: URL
    private let scanner: ShellFileScanner
    private let planner: ChangePlanner
    private let writer: ShellFileWriter
    private let backupStore: BackupStore
    private let repairService: QuarantineRepairService

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
        self.snapshot = EnvironmentSnapshot()
        self.selectedSection = .variables
        self.searchText = ""
        self.showsSensitiveValues = true
        self.backupRecords = []
        self.isLoading = false
        self.repairService = QuarantineRepairService()
        self.scanner = ShellFileScanner(homeDirectory: homeDirectory)
        self.planner = ChangePlanner(homeDirectory: homeDirectory)
        let backupStore = BackupStore(rootDirectory: homeDirectory)
        self.backupStore = backupStore
        self.writer = ShellFileWriter(backupStore: backupStore)
    }

    public var filteredVariables: [EnvVariable] {
        guard !searchText.isEmpty else { return snapshot.variables }
        let query = searchText.localizedLowercase
        return snapshot.variables.filter {
            $0.name.localizedLowercase.contains(query)
                || $0.value.localizedLowercase.contains(query)
                || $0.source.displayName.localizedLowercase.contains(query)
        }
    }

    public var selectedVariable: EnvVariable? {
        guard let selectedVariableID else { return filteredVariables.first }
        return snapshot.variables.first { $0.id == selectedVariableID }
    }

    public var selectedPathEntry: PathEntry? {
        guard let selectedPathEntryID else { return snapshot.pathEntries.first }
        return snapshot.pathEntries.first { $0.id == selectedPathEntryID }
    }

    public var selectedSource: ShellSource? {
        guard let selectedSourcePath else { return snapshot.sources.first }
        return snapshot.sources.first { $0.id == selectedSourcePath }
    }

    public var selectedSourceDetail: SourceDetail? {
        guard let source = selectedSource else { return nil }
        let content = (try? String(contentsOfFile: source.path, encoding: .utf8)) ?? ""
        let pathLines = snapshot.pathEntries
            .filter { $0.sourcePath == source.path && $0.lineNumber != nil && $0.rawLine != nil }
            .sorted { lhs, rhs in
                (lhs.lineNumber ?? 0, lhs.value) < (rhs.lineNumber ?? 0, rhs.value)
            }
        return SourceDetail(source: source, content: content, pathLines: pathLines)
    }

    public var pendingDiff: String {
        pendingChangeSet?.combinedDiff ?? ""
    }

    public var sourceCommands: [String] {
        pendingChangeSet?.sourceCommands ?? []
    }

    public var pendingChangeCount: Int {
        pendingChangeSet?.changes.filter { $0.original != $0.updated }.count ?? 0
    }

    public var hasUserEdits: Bool {
        snapshot.variables.contains { $0.source == .managed || $0.isTakenOver }
            || snapshot.pathEntries.contains { $0.sourcePath == nil }
    }

    public var warnings: [String] {
        var allWarnings = pendingChangeSet?.warnings ?? []
        allWarnings.append(contentsOf: pathDiagnostics)
        return Array(NSOrderedSet(array: allWarnings)) as? [String] ?? allWarnings
    }

    public var pathDiagnostics: [String] {
        var diagnostics: [String] = []
        for entry in snapshot.pathEntries where entry.isDuplicate {
            diagnostics.append("PATH 重复：\(entry.value)")
        }
        for entry in snapshot.pathEntries where entry.existsOnDisk == false {
            diagnostics.append("PATH 不存在：\(entry.value)")
        }
        return diagnostics
    }

    public func load() {
        do {
            let loaded = try EnvironmentLoader.loadState(homeDirectory: homeDirectory)
            applyLoadedState(loaded)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadAsync() async {
        isLoading = true
        do {
            let homeDirectory = homeDirectory
            let loaded = try await Task.detached(priority: .userInitiated) {
                try EnvironmentLoader.loadState(homeDirectory: homeDirectory)
            }.value
            applyLoadedState(loaded)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    public func reload() {
        load()
    }

    public func rebuildPlan() throws {
        pendingChangeSet = try planner.plan(snapshot: snapshot)
    }

    public func addVariable() {
        let variable = EnvVariable(name: "NEW_VARIABLE", value: "", isExported: true, isEnabled: true, source: .managed)
        snapshot.variables.append(variable)
        selectedVariableID = variable.id
        try? rebuildPlan()
    }

    public func updateVariable(_ variable: EnvVariable) {
        guard let index = snapshot.variables.firstIndex(where: { $0.id == variable.id }) else { return }
        snapshot.variables[index] = variable
        try? rebuildPlan()
    }

    public func deleteSelectedVariable() {
        guard let selectedVariableID else { return }
        snapshot.variables.removeAll { $0.id == selectedVariableID }
        self.selectedVariableID = snapshot.variables.first?.id
        try? rebuildPlan()
    }

    public func takeOver(variableID: EnvVariable.ID) {
        guard let index = snapshot.variables.firstIndex(where: { $0.id == variableID }) else { return }
        snapshot.variables[index].isTakenOver = true
        try? rebuildPlan()
    }

    public func addPathEntry() {
        let entry = PathEntry(value: "/usr/local/bin", isEnabled: true)
        snapshot.pathEntries.append(entry)
        selectedPathEntryID = entry.id
        markPathDuplicates()
        try? rebuildPlan()
    }

    public func updatePathEntry(_ entry: PathEntry) {
        guard let index = snapshot.pathEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        snapshot.pathEntries[index] = entry
        markPathDuplicates()
        try? rebuildPlan()
    }

    public func applyTemplate(_ template: EnvironmentTemplate) {
        for templateVariable in template.variables {
            if let index = snapshot.variables.firstIndex(where: { $0.name == templateVariable.name }) {
                snapshot.variables[index].value = templateVariable.value
                snapshot.variables[index].isExported = templateVariable.isExported
                snapshot.variables[index].isEnabled = true
                snapshot.variables[index].source = .managed
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
        for pathEntry in template.pathEntries where !existingPaths.contains(pathEntry) {
            snapshot.pathEntries.append(PathEntry(value: pathEntry, isEnabled: true))
        }
        markPathDuplicates()
        try? rebuildPlan()
    }

    public func applyKeychainReference(name: String, shellSnippet: String) {
        guard ShellSyntax.isValidVariableName(name) else {
            errorMessage = "Invalid shell variable name: \(name)"
            return
        }
        guard let equalsIndex = shellSnippet.firstIndex(of: "=") else { return }
        let value = String(shellSnippet[shellSnippet.index(after: equalsIndex)...])
        if let index = snapshot.variables.firstIndex(where: { $0.name == name }) {
            snapshot.variables[index].value = value
            snapshot.variables[index].isExported = true
            snapshot.variables[index].isEnabled = true
            snapshot.variables[index].source = .managed
        } else {
            snapshot.variables.append(EnvVariable(name: name, value: value, isExported: true, isEnabled: true, source: .managed))
        }
        try? rebuildPlan()
    }

    public func movePathEntry(fromOffsets offsets: IndexSet, toOffset offset: Int) {
        snapshot.pathEntries.moveElements(fromOffsets: offsets, toOffset: offset)
        markPathDuplicates()
        try? rebuildPlan()
    }

    public func deletePathEntries(at offsets: IndexSet) {
        snapshot.pathEntries.removeElements(atOffsets: offsets)
        selectedPathEntryID = snapshot.pathEntries.first?.id
        markPathDuplicates()
        try? rebuildPlan()
    }

    public func applyChanges() {
        do {
            let changeSet = try pendingChangeSet ?? planner.plan(snapshot: snapshot)
            lastApplyResult = try writer.apply(changeSet: changeSet)
            try loadBackups()
            try rebuildPlan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadBackups() throws {
        backupRecords = try backupStore.listBackups()
        selectedBackupID = backupRecords.first?.id
    }

    public func restoreSelectedBackup() throws {
        guard let selectedBackupID, let record = backupRecords.first(where: { $0.id == selectedBackupID }) else { return }
        try backupStore.restore(record)
        reload()
    }

    public func selectRepairApp(_ appURL: URL) {
        do {
            selectedRepairPlan = try repairService.planRepair(for: appURL)
            repairMessage = nil
        } catch {
            selectedRepairPlan = nil
            errorMessage = error.localizedDescription
        }
    }

    public func repairSelectedApp() {
        guard let selectedRepairPlan else { return }
        do {
            _ = try repairService.repair(for: URL(fileURLWithPath: selectedRepairPlan.appPath))
            repairMessage = "已修复：\(selectedRepairPlan.displayName)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func displayValue(for variable: EnvVariable) -> String {
        guard !showsSensitiveValues, variable.isLikelySensitive else { return variable.value }
        return String(repeating: "•", count: max(8, min(variable.value.count, 24)))
    }

    private func markPathDuplicates() {
        var seen: Set<String> = []
        snapshot.pathEntries = snapshot.pathEntries.map { entry in
            var updated = entry
            updated.isDuplicate = seen.contains(entry.value)
            if updated.isDuplicate {
                updated.isEnabled = false
            }
            seen.insert(entry.value)
            return updated
        }
    }

    private func applyLoadedState(_ loaded: LoadedEnvironmentState) {
        snapshot = loaded.snapshot
        selectedVariableID = snapshot.variables.first?.id
        selectedPathEntryID = snapshot.pathEntries.first?.id
        selectedSourcePath = snapshot.sources.first?.id
        backupRecords = loaded.backupRecords
        selectedBackupID = backupRecords.first?.id
        pendingChangeSet = loaded.changeSet
    }
}

public struct SourceDetail: Hashable, Sendable {
    public var source: ShellSource
    public var content: String
    public var pathLines: [PathEntry]

    public init(source: ShellSource, content: String, pathLines: [PathEntry]) {
        self.source = source
        self.content = content
        self.pathLines = pathLines
    }
}

private enum EnvironmentLoader {
    static func loadState(homeDirectory: URL) throws -> LoadedEnvironmentState {
        let snapshot = try ShellFileScanner(homeDirectory: homeDirectory).scan()
        let backups = try BackupStore(rootDirectory: homeDirectory).listBackups()
        let changeSet = try ChangePlanner(homeDirectory: homeDirectory).plan(snapshot: snapshot)
        return LoadedEnvironmentState(snapshot: snapshot, backupRecords: backups, changeSet: changeSet)
    }
}

private struct LoadedEnvironmentState: Sendable {
    var snapshot: EnvironmentSnapshot
    var backupRecords: [BackupRecord]
    var changeSet: ChangeSet
}

private extension Array {
    mutating func moveElements(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let moving = offsets.map { self[$0] }
        removeElements(atOffsets: offsets)
        let adjustedDestination = destination - offsets.filter { $0 < destination }.count
        insert(contentsOf: moving, at: Swift.max(0, Swift.min(adjustedDestination, count)))
    }

    mutating func removeElements(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            remove(at: index)
        }
    }
}

public enum AppSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case variables
    case path
    case diagnostics
    case guiEnvironment
    case projects
    case wizard
    case secrets
    case backups
    case tools

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .variables: "变量"
        case .path: "PATH"
        case .diagnostics: "诊断"
        case .guiEnvironment: "GUI 环境"
        case .projects: "项目"
        case .wizard: "向导"
        case .secrets: "密钥"
        case .backups: "备份"
        case .tools: "工具"
        }
    }

    public var systemImage: String {
        switch self {
        case .variables: "list.bullet.rectangle"
        case .path: "point.topleft.down.curvedto.point.bottomright.up"
        case .diagnostics: "stethoscope"
        case .guiEnvironment: "macwindow"
        case .projects: "folder.badge.gearshape"
        case .wizard: "wand.and.stars"
        case .secrets: "key"
        case .backups: "clock.arrow.circlepath"
        case .tools: "wrench.and.screwdriver"
        }
    }
}

public extension EnvVariableSource {
    var displayName: String {
        switch self {
        case .managed:
            "已托管"
        case .dotfile(let path):
            URL(fileURLWithPath: path).lastPathComponent
        case .unmanaged(let path):
            "未托管 \(URL(fileURLWithPath: path).lastPathComponent)"
        }
    }
}

public extension EnvVariable {
    var isLikelySensitive: Bool {
        let uppercased = name.uppercased()
        return ["KEY", "TOKEN", "SECRET", "PASSWORD"].contains { uppercased.contains($0) }
    }
}
