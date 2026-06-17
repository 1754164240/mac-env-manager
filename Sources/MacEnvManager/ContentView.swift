import AppKit
import MacEnvCore
import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: EnvironmentViewModel
    @State private var showsChangeSheet = false

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } content: {
            SectionListView(viewModel: viewModel)
        } detail: {
            DetailInspectorView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task {
                        await viewModel.loadAsync()
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
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private struct PendingApplyBar: View {
    @Bindable var viewModel: EnvironmentViewModel
    @Binding var showsChangeSheet: Bool

    var body: some View {
        if viewModel.pendingChangeCount > 0 {
            HStack(spacing: 12) {
                Label("\(viewModel.pendingChangeCount) 个文件待应用", systemImage: "circle.fill")
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
                    Label("应用", systemImage: "checkmark.circle")
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
                    Label("应用", systemImage: "checkmark.circle")
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
                Section("提示") {
                    ForEach(viewModel.warnings.prefix(3), id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                    }
                    if viewModel.warnings.count > 3 {
                        Text("+ \(viewModel.warnings.count - 3) 条")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Mac Env")
    }
}

private struct SectionListView: View {
    @Bindable var viewModel: EnvironmentViewModel

    var body: some View {
        Group {
            switch viewModel.selectedSection {
            case .variables:
                VariablesView(viewModel: viewModel)
            case .path:
                PathEditorView(viewModel: viewModel)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("工具")
                .font(.headline)

            Text("修复 macOS 提示应用已损坏或无法验证开发者的情况。")
                .foregroundStyle(.secondary)

            Button {
                selectApplication()
            } label: {
                Label("选择要修复的应用", systemImage: "app.badge")
            }
            .buttonStyle(.borderedProminent)

            if let plan = viewModel.selectedRepairPlan {
                VStack(alignment: .leading, spacing: 8) {
                    Text(plan.displayName)
                        .font(.headline)
                    Text(plan.appPath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                ContentUnavailableView("未选择应用", systemImage: "app.dashed", description: Text("选择提示“已损坏”或无法打开的 .app。"))
            }

            Spacer()
        }
        .padding()
        .navigationTitle("工具")
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
                TableColumn("值") { variable in
                    Text(viewModel.displayValue(for: variable))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                TableColumn("来源") { variable in
                    Text(variable.source.displayName)
                        .foregroundStyle(.secondary)
                }
                TableColumn("状态") { variable in
                    StatusBadge(variable: variable)
                }
            }
        }
        .navigationTitle("变量")
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
                Text("\(viewModel.snapshot.pathEntries.count) entries")
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch viewModel.selectedSection {
                case .variables:
                    VariableDetailView(viewModel: viewModel)
                case .path:
                    PathDetailView(viewModel: viewModel)
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

private struct RepairDetailView: View {
    @Bindable var viewModel: EnvironmentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("修复已损坏应用")
                .font(.title3.bold())

            Text("执行时系统会弹出管理员授权。")
                .foregroundStyle(.secondary)

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
                ContentUnavailableView("未选择应用", systemImage: "app.dashed", description: Text("请先在中间列表选择一个 .app 应用程序。"))
            }
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

            TextField("Name", text: $variable.name)
            TextEditor(text: $variable.value)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 92)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            Toggle("Export", isOn: $variable.isExported)
            Toggle("启用", isOn: $variable.isEnabled)
            Toggle("明文显示敏感值", isOn: $viewModel.showsSensitiveValues)

            DisclosureGroup("来源", isExpanded: $showsSource) {
                VariableSourceView(variable: variable)
            }

            HStack {
                Button("保存到计划") {
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

            GroupBox("Generated Shell") {
                Text(generatedShell(for: variable))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        GroupBox("Diff Preview") {
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
        if !variable.isEnabled { return "disabled" }
        if case .managed = variable.source { return "managed" }
        return "importable"
    }

    private var color: Color {
        if !variable.isEnabled { return .secondary }
        if case .managed = variable.source { return .green }
        return .orange
    }
}
