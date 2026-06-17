import AppKit
import MacEnvCore
import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: EnvironmentViewModel
    @Bindable var proViewModel: ProEnvironmentViewModel
    @State private var showsChangeSheet = false

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } content: {
            SectionListView(viewModel: viewModel, proViewModel: proViewModel)
        } detail: {
            DetailInspectorView(viewModel: viewModel, proViewModel: proViewModel)
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task {
                        await viewModel.loadAsync()
                        proViewModel.refreshDiagnostics(snapshot: viewModel.snapshot, guiVariables: proViewModel.guiVariables)
                    }
                } label: {
                    Label("重新加载", systemImage: "arrow.clockwise")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            PendingApplyBar(viewModel: viewModel, showsChangeSheet: $showsChangeSheet)
        }
        .sheet(isPresented: $showsChangeSheet) {
            ChangePreviewSheet(viewModel: viewModel)
        }
        .alert("操作失败", isPresented: errorBinding) {
            Button("好") {
                viewModel.errorMessage = nil
                proViewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? proViewModel.errorMessage ?? "")
        }
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                ProgressView("正在扫描 shell 配置...")
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 12)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil || proViewModel.errorMessage != nil },
            set: {
                if !$0 {
                    viewModel.errorMessage = nil
                    proViewModel.errorMessage = nil
                }
            }
        )
    }
}

private struct PendingApplyBar: View {
    @Bindable var viewModel: EnvironmentViewModel
    @Binding var showsChangeSheet: Bool

    var body: some View {
        if viewModel.pendingChangeCount > 0 {
            HStack(spacing: 12) {
                Label(applyBarTitle, systemImage: viewModel.hasUserEdits ? "pencil.circle.fill" : "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showsChangeSheet = true
                } label: {
                    Label("查看变更", systemImage: "doc.text.magnifyingglass")
                }
                Button {
                    viewModel.applyChanges()
                } label: {
                    Label("写入文件", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }

    private var applyBarTitle: String {
        if viewModel.hasUserEdits {
            return "\(viewModel.pendingChangeCount) 个文件待写入"
        }
        return "\(viewModel.pendingChangeCount) 个初始化建议"
    }
}

private struct ChangePreviewSheet: View {
    @Bindable var viewModel: EnvironmentViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("变更预览")
                    .font(.title3.bold())
                Spacer()
                Button("关闭") {
                    dismiss()
                }
            }

            ScrollView {
                DiffPreviewView(viewModel: viewModel)
                    .padding(.vertical, 4)
            }

            HStack {
                Spacer()
                Button {
                    viewModel.applyChanges()
                    dismiss()
                } label: {
                    Label("写入文件", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.pendingChangeCount == 0)
            }
        }
        .padding()
        .frame(minWidth: 760, minHeight: 520)
    }
}

private struct SidebarView: View {
    @Bindable var viewModel: EnvironmentViewModel

    var body: some View {
        List(selection: $viewModel.selectedSection) {
            Section("工作区") {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }

            if !viewModel.warnings.isEmpty {
                Section("诊断") {
                    Label("\(viewModel.warnings.count) 条提示", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle("Mac Env")
    }
}

private struct SectionListView: View {
    @Bindable var viewModel: EnvironmentViewModel
    @Bindable var proViewModel: ProEnvironmentViewModel

    var body: some View {
        Group {
            switch viewModel.selectedSection {
            case .variables:
                VariablesView(viewModel: viewModel)
            case .path:
                PathEditorView(viewModel: viewModel)
            case .diagnostics:
                DiagnosticsView(viewModel: viewModel, proViewModel: proViewModel)
            case .guiEnvironment:
                GUIEnvironmentView(proViewModel: proViewModel)
            case .projects:
                ProjectsView(proViewModel: proViewModel)
            case .wizard:
                WizardView(proViewModel: proViewModel)
            case .secrets:
                SecretsView(proViewModel: proViewModel)
            case .backups:
                BackupsView(viewModel: viewModel)
            case .tools:
                ToolsView(viewModel: viewModel)
            }
        }
    }
}

private struct ToolsView: View {
    @Bindable var viewModel: EnvironmentViewModel

    var body: some View {
        List(selection: .constant("repair")) {
            Text("工具")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text("修复已损坏应用")
                    Text("移除 quarantine 隔离属性")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tag("repair")
        }
        .navigationTitle("工具")
    }
}

private struct DiagnosticsView: View {
    @Bindable var viewModel: EnvironmentViewModel
    @Bindable var proViewModel: ProEnvironmentViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("环境诊断")
                    .font(.headline)
                Spacer()
                Button {
                    proViewModel.refreshDiagnostics(snapshot: viewModel.snapshot, guiVariables: proViewModel.guiVariables)
                } label: {
                    Label("重新诊断", systemImage: "stethoscope")
                }
            }
            .padding()

            if proViewModel.diagnostics.isEmpty {
                ContentUnavailableView("没有诊断提示", systemImage: "checkmark.circle", description: Text("当前 shell 配置没有发现需要处理的问题。"))
            } else {
                List(proViewModel.diagnostics) { diagnostic in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(diagnostic.title, systemImage: diagnostic.severity.systemImage)
                            .foregroundStyle(diagnostic.severity.color)
                        Text(diagnostic.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let actionTitle = diagnostic.actionTitle {
                            Text(actionTitle)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("诊断")
        .navigationSplitViewColumnWidth(min: 520, ideal: 660, max: 820)
    }
}

private struct GUIEnvironmentView: View {
    @Bindable var proViewModel: ProEnvironmentViewModel

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("GUI 应用环境") {
                    TextField("变量名", text: $proViewModel.guiVariableName)
                        .font(.system(.body, design: .monospaced))
                    TextField("变量值", text: $proViewModel.guiVariableValue)
                        .font(.system(.body, design: .monospaced))
                    HStack {
                        Button("读取") {
                            proViewModel.buildGUIGetPlan()
                        }
                        Button("设置") {
                            proViewModel.buildGUISetPlan()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("删除") {
                            proViewModel.buildGUIUnsetPlan()
                        }
                    }
                }
            }
            .formStyle(.grouped)

            if !proViewModel.guiCommandResults.isEmpty {
                CommandResultList(results: proViewModel.guiCommandResults)
                    .frame(maxHeight: 220)
            }
        }
        .navigationTitle("GUI 环境")
    }
}

private struct ProjectsView: View {
    @Bindable var proViewModel: ProEnvironmentViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    selectProject()
                } label: {
                    Label("选择项目目录", systemImage: "folder")
                }
                Button {
                    proViewModel.projectVariableKey = "NEW_KEY"
                    proViewModel.projectVariableValue = ""
                } label: {
                    Label("新增变量", systemImage: "plus")
                }
                Spacer()
                Text(proViewModel.projectDirectory?.path ?? "尚未选择项目")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding()

            if let snapshot = proViewModel.projectSnapshot {
                VStack(spacing: 10) {
                    Picker("目标文件", selection: $proViewModel.selectedProjectEnvFileName) {
                        ForEach(projectFileOptions(from: snapshot), id: \.self) { fileName in
                            Text(fileName).tag(fileName)
                        }
                    }
                    .pickerStyle(.menu)
                    TextField("变量名", text: $proViewModel.projectVariableKey)
                        .font(.system(.body, design: .monospaced))
                    TextField("变量值", text: $proViewModel.projectVariableValue)
                        .font(.system(.body, design: .monospaced))
                    HStack {
                        Button("生成预览") {
                            try? proViewModel.planProjectEnvWrite()
                        }
                        Button("写入 .env") {
                            do {
                                try proViewModel.planProjectEnvWrite()
                                try proViewModel.applyProjectEnvWrite()
                            } catch {
                                proViewModel.errorMessage = error.localizedDescription
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                Table(snapshot.variables, selection: $proViewModel.selectedProjectVariableID) {
                    TableColumn("键", value: \.key)
                        .width(min: 140, ideal: 200)
                    TableColumn("值") { variable in
                        Text(variable.value)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(min: 180, ideal: 260)
                    TableColumn("文件", value: \.fileName)
                        .width(120)
                    TableColumn("状态") { variable in
                        if variable.isDuplicate {
                            Text("重复")
                                .foregroundStyle(.orange)
                        } else if variable.value.isEmpty {
                            Text("空值")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("正常")
                                .foregroundStyle(.green)
                        }
                    }
                    .width(80)
                }
                .onChange(of: proViewModel.selectedProjectVariableID) { _, newValue in
                    proViewModel.selectProjectVariable(id: newValue)
                }
            } else {
                ContentUnavailableView("选择项目后扫描 .env", systemImage: "folder.badge.gearshape", description: Text("支持 .env、.env.local、.env.development、.env.production 和 .envrc。"))
            }
        }
        .navigationTitle("项目")
        .navigationSplitViewColumnWidth(min: 520, ideal: 660, max: 820)
    }

    private func selectProject() {
        let panel = NSOpenPanel()
        panel.title = "选择项目目录"
        panel.prompt = "选择"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            try? proViewModel.scanProject(at: url)
        }
    }

    private func projectFileOptions(from snapshot: ProjectEnvSnapshot) -> [String] {
        let existing = snapshot.files.map(\.name)
        return Array(NSOrderedSet(array: existing + ProjectEnvScanner.supportedFileNames)) as? [String] ?? ProjectEnvScanner.supportedFileNames
    }
}

private struct WizardView: View {
    @Bindable var proViewModel: ProEnvironmentViewModel

    var body: some View {
        List(selection: $proViewModel.selectedTemplateID) {
            ForEach(proViewModel.catalog.templates) { template in
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.title)
                    Text(template.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(template.id)
            }
        }
        .navigationTitle("向导")
    }
}

private struct SecretsView: View {
    @Bindable var proViewModel: ProEnvironmentViewModel

    var body: some View {
        Form {
            Section("Keychain 密钥") {
                TextField("变量名", text: $proViewModel.secretName)
                    .font(.system(.body, design: .monospaced))
                SecureField("变量值", text: $proViewModel.secretValue)
                    .font(.system(.body, design: .monospaced))
                HStack {
                    Button("保存计划") {
                        proViewModel.buildKeychainSavePlan()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("读取计划") {
                        proViewModel.buildKeychainReadPlan()
                    }
                    Button("删除计划") {
                        proViewModel.buildKeychainDeletePlan()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("密钥")
    }
}

private struct VariablesView: View {
    @Bindable var viewModel: EnvironmentViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("搜索名称、值或来源", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    viewModel.addVariable()
                } label: {
                    Label("新增", systemImage: "plus")
                }
            }
            .padding()

            Table(viewModel.filteredVariables, selection: $viewModel.selectedVariableID) {
                TableColumn("启用") { variable in
                    Image(systemName: variable.isEnabled ? "checkmark.circle.fill" : "minus.circle")
                        .foregroundStyle(variable.isEnabled ? .green : .secondary)
                }
                .width(48)

                TableColumn("名称", value: \.name)
                    .width(min: 160, ideal: 220)
                TableColumn("值") { variable in
                    Text(viewModel.displayValue(for: variable))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .width(min: 180, ideal: 280)
                TableColumn("来源") { variable in
                    Text(variable.source.displayName)
                        .foregroundStyle(.secondary)
                }
                .width(88)
                TableColumn("状态") { variable in
                    StatusBadge(variable: variable)
                }
                .width(88)
            }
        }
        .navigationTitle("变量")
        .navigationSplitViewColumnWidth(min: 520, ideal: 660, max: 820)
    }
}

private struct PathEditorView: View {
    @Bindable var viewModel: EnvironmentViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    viewModel.addPathEntry()
                } label: {
                    Label("新增路径", systemImage: "plus")
                }
                Spacer()
                Text("\(viewModel.snapshot.pathEntries.count) 项")
                    .foregroundStyle(.secondary)
            }
            .padding()

            List(selection: $viewModel.selectedPathEntryID) {
                ForEach(viewModel.snapshot.pathEntries) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(entry.isEnabled ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.value)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(entry.sourceDisplayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        if entry.isDuplicate {
                            Text("重复")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if entry.existsOnDisk == false {
                            Text("不存在")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .tag(entry.id)
                }
                .onMove(perform: viewModel.movePathEntry)
                .onDelete(perform: viewModel.deletePathEntries)
            }
        }
        .navigationTitle("PATH")
        .navigationSplitViewColumnWidth(min: 520, ideal: 660, max: 820)
    }
}

private struct BackupsView: View {
    @Bindable var viewModel: EnvironmentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("备份记录")
                    .font(.headline)
                Spacer()
                Button {
                    try? viewModel.loadBackups()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }

            if viewModel.backupRecords.isEmpty {
                ContentUnavailableView("还没有备份", systemImage: "clock.arrow.circlepath", description: Text("应用更改前会自动创建时间戳备份。"))
            } else {
                List(viewModel.backupRecords, selection: $viewModel.selectedBackupID) { backup in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(backup.originalPath)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(backup.backupPath)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(backup.createdAt.formatted(date: .abbreviated, time: .standard))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .tag(backup.id)
                }
            }

            Button("恢复选中备份") {
                try? viewModel.restoreSelectedBackup()
            }
            .disabled(viewModel.selectedBackupID == nil)
        }
        .padding()
        .navigationTitle("备份")
    }
}

private struct DetailInspectorView: View {
    @Bindable var viewModel: EnvironmentViewModel
    @Bindable var proViewModel: ProEnvironmentViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch viewModel.selectedSection {
                case .variables:
                    VariableDetailView(viewModel: viewModel)
                case .path:
                    PathDetailView(viewModel: viewModel)
                case .diagnostics:
                    DiagnosticsDetailView(proViewModel: proViewModel)
                case .guiEnvironment:
                    GUIEnvironmentDetailView(proViewModel: proViewModel)
                case .projects:
                    ProjectsDetailView(proViewModel: proViewModel)
                case .wizard:
                    WizardDetailView(viewModel: viewModel, proViewModel: proViewModel)
                case .secrets:
                    SecretsDetailView(viewModel: viewModel, proViewModel: proViewModel)
                case .backups:
                    ApplyResultView(viewModel: viewModel)
                case .tools:
                    RepairDetailView(viewModel: viewModel)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("详情")
    }
}

private struct DiagnosticsDetailView: View {
    @Bindable var proViewModel: ProEnvironmentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("诊断摘要")
                .font(.title3.bold())
            LabeledContent("提示数量") {
                Text("\(proViewModel.diagnostics.count)")
            }
            ForEach(DiagnosticSeverity.allCasesForUI, id: \.self) { severity in
                LabeledContent(severity.title) {
                    Text("\(proViewModel.diagnostics.filter { $0.severity == severity }.count)")
                }
            }
        }
    }
}

private struct GUIEnvironmentDetailView: View {
    @Bindable var proViewModel: ProEnvironmentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("launchctl 命令")
                .font(.title3.bold())
            Text("GUI 应用环境由 launchd 继承。设置后通常需要重启目标应用才会生效。")
                .foregroundStyle(.secondary)
            CommandPlanPreview(plan: proViewModel.pendingGUIPlan) {
                proViewModel.runPendingGUIPlan()
            }
        }
    }
}

private struct ProjectsDetailView: View {
    @Bindable var proViewModel: ProEnvironmentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("项目环境")
                .font(.title3.bold())
            if let snapshot = proViewModel.projectSnapshot {
                LabeledContent("项目") {
                    Text(snapshot.projectDirectory)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                LabeledContent("文件") {
                    Text("\(snapshot.files.count)")
                }
                LabeledContent("变量") {
                    Text("\(snapshot.variables.count)")
                }
                LabeledContent("重复键") {
                    Text("\(snapshot.variables.filter(\.isDuplicate).count)")
                }
                GroupBox(".envrc 示例") {
                    Text(ProjectEnvWriter(projectDirectory: URL(fileURLWithPath: snapshot.projectDirectory)).direnvContent(forEnvFile: ".env"))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let change = proViewModel.pendingProjectChange {
                    GroupBox("变更预览") {
                        Text(change.diff.isEmpty ? "没有变化" : change.diff)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let result = proViewModel.projectApplyResult {
                    LabeledContent("备份") {
                        Text("\(result.backups.count)")
                    }
                }
            } else {
                Text("选择项目后会在这里显示扫描摘要。")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WizardDetailView: View {
    @Bindable var viewModel: EnvironmentViewModel
    @Bindable var proViewModel: ProEnvironmentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let template = proViewModel.selectedTemplate {
                Text(template.title)
                    .font(.title3.bold())
                Text(template.summary)
                    .foregroundStyle(.secondary)
                GroupBox("应用预览") {
                    Text(proViewModel.templatePreview)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button {
                    viewModel.applyTemplate(template)
                    proViewModel.refreshDiagnostics(snapshot: viewModel.snapshot, guiVariables: proViewModel.guiVariables)
                } label: {
                    Label("加入待写入", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                if !template.installCommands.isEmpty {
                    Text("一键安装")
                        .font(.headline)
                    ForEach(template.installCommands) { plan in
                        HStack {
                            Text(plan.previewCommand)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            Button("执行") {
                                proViewModel.runInstallCommand(plan)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                if !proViewModel.templateCommandResults.isEmpty {
                    CommandResultList(results: proViewModel.templateCommandResults)
                }
            } else {
                ContentUnavailableView("未选择向导", systemImage: "wand.and.stars")
            }
        }
    }
}

private struct SecretsDetailView: View {
    @Bindable var viewModel: EnvironmentViewModel
    @Bindable var proViewModel: ProEnvironmentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keychain 命令")
                .font(.title3.bold())
            CommandPlanPreview(plan: proViewModel.pendingKeychainPlan) {
                proViewModel.runPendingKeychainPlan()
            }
            if !proViewModel.keychainShellSnippet.isEmpty {
                GroupBox("Shell 读取示例") {
                    Text(proViewModel.keychainShellSnippet)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button {
                    viewModel.applyKeychainReference(name: proViewModel.secretName, shellSnippet: proViewModel.keychainShellSnippet)
                    proViewModel.refreshDiagnostics(snapshot: viewModel.snapshot, guiVariables: proViewModel.guiVariables)
                } label: {
                    Label("加入待写入", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            if !proViewModel.keychainCommandResults.isEmpty {
                CommandResultList(results: proViewModel.keychainCommandResults)
            }
        }
    }
}

private struct RepairDetailView: View {
    @Bindable var viewModel: EnvironmentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("修复已损坏应用")
                .font(.title3.bold())

            Text("选择一个提示“已损坏”或“无法验证开发者”的 .app，移除 macOS 隔离属性。")
                .foregroundStyle(.secondary)

            Button {
                selectApplication()
            } label: {
                Label("选择应用程序", systemImage: "app.badge")
            }
            .buttonStyle(.borderedProminent)

            if let plan = viewModel.selectedRepairPlan {
                LabeledContent("应用") {
                    Text(plan.displayName)
                }

                LabeledContent("路径") {
                    Text(plan.appPath)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }

                GroupBox("将执行的命令") {
                    Text(plan.terminalCommand)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    viewModel.repairSelectedApp()
                } label: {
                    Label("修复选中应用", systemImage: "wrench.and.screwdriver.fill")
                }
                .buttonStyle(.borderedProminent)

                if let repairMessage = viewModel.repairMessage {
                    Label(repairMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            } else {
                Text("尚未选择应用")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func selectApplication() {
        let panel = NSOpenPanel()
        panel.title = "选择要修复的应用程序"
        panel.prompt = "选择"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.selectRepairApp(url)
        }
    }
}

private struct VariableDetailView: View {
    @Bindable var viewModel: EnvironmentViewModel

    var body: some View {
        if let variable = viewModel.selectedVariable {
            EditableVariableForm(viewModel: viewModel, variable: variable)
        } else {
            ContentUnavailableView("未选择变量", systemImage: "list.bullet.rectangle")
        }
    }
}

private struct EditableVariableForm: View {
    @Bindable var viewModel: EnvironmentViewModel
    @State var variable: EnvVariable
    @State private var showsSource = false
    @State private var showsShellPreview = false
    @State private var showsChanges = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(variable.name)
                    .font(.title3.bold())
                if variable.isLikelySensitive {
                    Text("疑似敏感")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.15), in: Capsule())
                }
            }

            TextField("变量名", text: $variable.name)
            TextEditor(text: $variable.value)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 92)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            Toggle("导出 export", isOn: $variable.isExported)
            Toggle("启用", isOn: $variable.isEnabled)
            Toggle("明文显示敏感值", isOn: $viewModel.showsSensitiveValues)

            DisclosureGroup("来源", isExpanded: $showsSource) {
                VariableSourceView(variable: variable)
            }

            HStack {
                Button("加入待写入") {
                    viewModel.updateVariable(variable)
                }
                .buttonStyle(.borderedProminent)
                Button("删除") {
                    viewModel.deleteSelectedVariable()
                }
                if case .dotfile = variable.source {
                    Button("接管到托管文件") {
                        viewModel.takeOver(variableID: variable.id)
                    }
                }
            }

            DisclosureGroup("Shell 预览", isExpanded: $showsShellPreview) {
                GroupBox {
                    Text(generatedShell(for: variable))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            DisclosureGroup("变更预览", isExpanded: $showsChanges) {
                DiffPreviewView(viewModel: viewModel)
            }
        }
        .onChange(of: viewModel.selectedVariableID) { _, _ in
            if let selected = viewModel.selectedVariable {
                variable = selected
            }
        }
    }

    private func generatedShell(for variable: EnvVariable) -> String {
        let prefix = variable.isExported ? "export " : ""
        let line = "\(prefix)\(variable.name)=\(ShellSyntax.shellSingleQuote(variable.value))"
        return variable.isEnabled ? line : "# \(line) \(ShellSyntax.disabledMarker)"
    }
}

private struct VariableSourceView: View {
    let variable: EnvVariable

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("来源") {
                Text(variable.source.displayName)
            }
            if case .dotfile(let path) = variable.source {
                LabeledContent("文件") {
                    Text(path)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            if variable.isTakenOver {
                Label("已计划接管到托管文件", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PathDetailView: View {
    @Bindable var viewModel: EnvironmentViewModel
    @State private var showsChanges = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PATH 诊断")
                .font(.title3.bold())
            if let entry = viewModel.selectedPathEntry {
                EditablePathEntryForm(viewModel: viewModel, entry: entry)
                Divider()
            }
            if viewModel.pathDiagnostics.isEmpty {
                Label("没有发现重复或缺失路径", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            } else {
                ForEach(viewModel.pathDiagnostics, id: \.self) { diagnostic in
                    Label(diagnostic, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            DisclosureGroup("变更预览", isExpanded: $showsChanges) {
                DiffPreviewView(viewModel: viewModel)
            }
        }
    }
}

private struct EditablePathEntryForm: View {
    @Bindable var viewModel: EnvironmentViewModel
    @State var entry: PathEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选中路径")
                .font(.headline)
            TextField("Path", text: $entry.value)
                .font(.system(.body, design: .monospaced))
            Toggle("启用", isOn: $entry.isEnabled)
            LabeledContent("来源文件") {
                Text(entry.sourcePath ?? "未保存到文件")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            LabeledContent("行号") {
                Text(entry.lineNumber.map(String.init) ?? "-")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            if let rawLine = entry.rawLine, !rawLine.isEmpty {
                GroupBox("原始 PATH 设置") {
                    Text(rawLine)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Button("保存路径") {
                viewModel.updatePathEntry(entry)
            }
            .buttonStyle(.borderedProminent)
        }
        .onChange(of: viewModel.selectedPathEntryID) { _, _ in
            if let selected = viewModel.selectedPathEntry {
                entry = selected
            }
        }
    }
}

private extension PathEntry {
    var sourceDisplayName: String {
        guard let sourcePath else {
            return "新建路径，尚未写入文件"
        }
        let fileName = URL(fileURLWithPath: sourcePath).lastPathComponent
        guard let lineNumber else {
            return fileName
        }
        return "\(fileName):\(lineNumber)"
    }
}

private struct DiffPreviewView: View {
    @Bindable var viewModel: EnvironmentViewModel

    var body: some View {
        GroupBox("变更内容") {
            if viewModel.pendingDiff.isEmpty {
                Text("没有待应用更改")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(viewModel.pendingDiff)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        if !viewModel.sourceCommands.isEmpty {
            GroupBox("应用后运行") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.sourceCommands, id: \.self) { command in
                        Text(command)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct CommandPlanPreview: View {
    let plan: CommandPlan?
    let run: () -> Void

    var body: some View {
        GroupBox("命令预览") {
            VStack(alignment: .leading, spacing: 10) {
                if let plan {
                    Text(plan.previewCommand)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        run()
                    } label: {
                        Label("执行命令", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("先在中间栏填写内容并生成计划。")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct CommandResultList: View {
    let results: [CommandResult]

    var body: some View {
        GroupBox("执行结果") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(results, id: \.startedAt) { result in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(result.plan.title)
                                .font(.caption.bold())
                            Spacer()
                            Text("退出码 \(result.exitCode)")
                                .font(.caption)
                                .foregroundStyle(result.exitCode == 0 ? .green : .red)
                        }
                        if !result.stdout.isEmpty {
                            Text(result.stdout)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        if !result.stderr.isEmpty {
                            Text(result.stderr)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                        }
                    }
                    Divider()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension DiagnosticSeverity {
    static var allCasesForUI: [DiagnosticSeverity] {
        [.error, .warning, .info]
    }

    var title: String {
        switch self {
        case .info: "信息"
        case .warning: "警告"
        case .error: "错误"
        }
    }

    var systemImage: String {
        switch self {
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }

    var color: Color {
        switch self {
        case .info: .blue
        case .warning: .orange
        case .error: .red
        }
    }
}

private struct ApplyResultView: View {
    @Bindable var viewModel: EnvironmentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("应用结果")
                .font(.title3.bold())
            if let result = viewModel.lastApplyResult {
                Text("备份：\(result.backups.count)")
                ForEach(result.sourceCommands, id: \.self) { command in
                    Text(command)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            } else {
                Text("还没有应用更改")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StatusBadge: View {
    let variable: EnvVariable

    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private var title: String {
        if !variable.isEnabled { return "已停用" }
        if case .managed = variable.source { return "已托管" }
        return "可接管"
    }

    private var color: Color {
        if !variable.isEnabled { return .secondary }
        if case .managed = variable.source { return .green }
        return .orange
    }
}
