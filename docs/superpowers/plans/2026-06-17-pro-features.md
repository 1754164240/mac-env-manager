# Mac Env Manager Pro Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不做分发能力的前提下，为 Mac Env Manager 增加诊断、GUI 环境、项目 `.env`、Keychain、模板向导和安全的一键安装。

**Architecture:** 新功能放在 `MacEnvCore` 的独立服务里，通过新的 `ProEnvironmentViewModel` 暴露给 SwiftUI。现有 shell 管理服务保持原有职责，只在导航和诊断输入上与新模块集成。

**Tech Stack:** Swift 5.9、SwiftUI、Observation、Foundation、XCTest、macOS shell 命令。

---

## 文件结构

- 新建 `Sources/MacEnvCore/CommandRunner.swift`：命令计划、执行结果、可注入 runner。
- 新建 `Sources/MacEnvCore/EnvironmentDiagnostics.swift`：诊断模型和诊断服务。
- 新建 `Sources/MacEnvCore/GUIEnvironmentService.swift`：launchctl 环境变量读取、写入和删除计划。
- 新建 `Sources/MacEnvCore/ProjectEnvService.swift`：项目 `.env` / `.envrc` 扫描、规划、写入。
- 新建 `Sources/MacEnvCore/KeychainSecretStore.swift`：Keychain 命令生成、保存、读取、删除。
- 新建 `Sources/MacEnvCore/EnvironmentTemplateCatalog.swift`：模板定义、检测和安装计划。
- 新建 `Sources/MacEnvCore/ProEnvironmentViewModel.swift`：新功能页面状态。
- 修改 `Sources/MacEnvCore/Models.swift`：增加新来源类型和聚合模型。
- 修改 `Sources/MacEnvCore/EnvironmentViewModel.swift`：导航分区扩展。
- 修改 `Sources/MacEnvManager/ContentView.swift`：增加诊断、GUI 环境、项目、向导、密钥页面。
- 新建对应测试文件到 `Tests/MacEnvCoreTests/`。
- 修改 `README.md`：中文说明新增 Pro 功能。

## Task 1: 命令执行基础设施

**Files:**
- Create: `Sources/MacEnvCore/CommandRunner.swift`
- Test: `Tests/MacEnvCoreTests/CommandRunnerTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
func testShellCommandRunnerCapturesOutputAndExitCode() throws {
    let runner = ShellCommandRunner()
    let result = try runner.run(CommandPlan(title: "echo", executable: "/bin/sh", arguments: ["-c", "printf hello"]))
    XCTAssertEqual(result.exitCode, 0)
    XCTAssertEqual(result.stdout, "hello")
    XCTAssertEqual(result.stderr, "")
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter CommandRunnerTests`
Expected: 编译失败，因为 `ShellCommandRunner` 和 `CommandPlan` 尚未定义。

- [ ] **Step 3: 实现最小代码**

创建 `CommandPlan`、`CommandResult`、`CommandRunning` 和 `ShellCommandRunner`。runner 使用 `Process`，捕获 stdout/stderr，返回退出码和时间。

- [ ] **Step 4: 验证通过**

Run: `swift test --filter CommandRunnerTests`
Expected: PASS。

## Task 2: GUI 环境服务

**Files:**
- Create: `Sources/MacEnvCore/GUIEnvironmentService.swift`
- Test: `Tests/MacEnvCoreTests/GUIEnvironmentServiceTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
func testSetenvPlanQuotesValueAndUsesLaunchctl() {
    let service = GUIEnvironmentService()
    let plan = service.setPlan(name: "HTTP_PROXY", value: "http://127.0.0.1:7897")
    XCTAssertEqual(plan.executable, "/bin/launchctl")
    XCTAssertEqual(plan.arguments, ["setenv", "HTTP_PROXY", "http://127.0.0.1:7897"])
    XCTAssertEqual(plan.previewCommand, "launchctl setenv HTTP_PROXY 'http://127.0.0.1:7897'")
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter GUIEnvironmentServiceTests`
Expected: 编译失败，因为服务不存在。

- [ ] **Step 3: 实现服务**

实现 `getPlan(name:)`、`setPlan(name:value:)`、`unsetPlan(name:)` 和 `parseGetenvResult(_:)`。

- [ ] **Step 4: 验证通过**

Run: `swift test --filter GUIEnvironmentServiceTests`
Expected: PASS。

## Task 3: 项目 env 服务

**Files:**
- Create: `Sources/MacEnvCore/ProjectEnvService.swift`
- Test: `Tests/MacEnvCoreTests/ProjectEnvServiceTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
func testScannerReadsEnvFilesAndReportsDuplicates() throws {
    let root = try TemporaryHome.make()
    try root.write(".env", "API_URL=https://example.com\nTOKEN=abc\n")
    try root.write(".env.local", "TOKEN=override\nEMPTY=\n")
    let scanner = ProjectEnvScanner(projectDirectory: root.url)
    let snapshot = try scanner.scan()
    XCTAssertEqual(snapshot.files.count, 2)
    XCTAssertTrue(snapshot.variables.contains { $0.key == "TOKEN" && $0.isDuplicate })
    XCTAssertTrue(snapshot.variables.contains { $0.key == "EMPTY" && $0.value.isEmpty })
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter ProjectEnvServiceTests`
Expected: 编译失败，因为类型不存在。

- [ ] **Step 3: 实现扫描和写入计划**

实现 `.env` 解析、重复键标记、`.envrc` direnv 内容生成、写入前 diff 和备份路径规划。

- [ ] **Step 4: 验证通过**

Run: `swift test --filter ProjectEnvServiceTests`
Expected: PASS。

## Task 4: Keychain 服务

**Files:**
- Create: `Sources/MacEnvCore/KeychainSecretStore.swift`
- Test: `Tests/MacEnvCoreTests/KeychainSecretStoreTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
func testSavePlanUsesSecurityAddGenericPassword() {
    let store = KeychainSecretStore()
    let plan = store.savePlan(account: "OPENAI_API_KEY", value: "secret")
    XCTAssertEqual(plan.executable, "/usr/bin/security")
    XCTAssertEqual(plan.arguments, ["add-generic-password", "-U", "-s", "Mac Env Manager", "-a", "OPENAI_API_KEY", "-w", "secret"])
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter KeychainSecretStoreTests`
Expected: 编译失败，因为类型不存在。

- [ ] **Step 3: 实现 Keychain 命令计划**

实现保存、读取、删除计划和 shell 读取示例生成。

- [ ] **Step 4: 验证通过**

Run: `swift test --filter KeychainSecretStoreTests`
Expected: PASS。

## Task 5: 模板目录和安装计划

**Files:**
- Create: `Sources/MacEnvCore/EnvironmentTemplateCatalog.swift`
- Test: `Tests/MacEnvCoreTests/EnvironmentTemplateCatalogTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
func testCatalogContainsRequiredTemplatesAndProxyVariables() {
    let catalog = EnvironmentTemplateCatalog.defaultCatalog()
    XCTAssertTrue(catalog.templates.map(\.id).contains("proxy"))
    let proxy = catalog.templates.first { $0.id == "proxy" }
    XCTAssertTrue(proxy?.variables.contains { $0.name == "https_proxy" } == true)
    XCTAssertTrue(catalog.templates.contains { $0.installCommands.isEmpty == false })
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter EnvironmentTemplateCatalogTests`
Expected: 编译失败，因为目录类型不存在。

- [ ] **Step 3: 实现模板**

实现 Homebrew、Node、Python、Java、Android、Go、Rust、代理模板；每个模板带检测命令、变量、PATH 和安装命令。

- [ ] **Step 4: 验证通过**

Run: `swift test --filter EnvironmentTemplateCatalogTests`
Expected: PASS。

## Task 6: 诊断服务

**Files:**
- Create: `Sources/MacEnvCore/EnvironmentDiagnostics.swift`
- Test: `Tests/MacEnvCoreTests/EnvironmentDiagnosticsTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
func testDiagnosticsReportMissingPathProxyGroupAndSensitivePlaintext() {
    let snapshot = EnvironmentSnapshot(
        variables: [EnvVariable(name: "API_TOKEN", value: "plain", source: .managed)],
        pathEntries: [PathEntry(value: "/missing", existsOnDisk: false)]
    )
    let diagnostics = EnvironmentDiagnosticsService().diagnose(snapshot: snapshot, guiVariables: [], toolChecks: [])
    XCTAssertTrue(diagnostics.contains { $0.title.contains("PATH 不存在") })
    XCTAssertTrue(diagnostics.contains { $0.title.contains("代理变量不完整") })
    XCTAssertTrue(diagnostics.contains { $0.title.contains("疑似敏感变量") })
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter EnvironmentDiagnosticsTests`
Expected: 编译失败，因为诊断服务不存在。

- [ ] **Step 3: 实现诊断服务**

实现严重级别、诊断项、建议动作和聚合逻辑。

- [ ] **Step 4: 验证通过**

Run: `swift test --filter EnvironmentDiagnosticsTests`
Expected: PASS。

## Task 7: Pro ViewModel

**Files:**
- Create: `Sources/MacEnvCore/ProEnvironmentViewModel.swift`
- Test: `Tests/MacEnvCoreTests/ProEnvironmentViewModelTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
@MainActor
func testViewModelSelectsTemplateAndBuildsInstallPreview() {
    let viewModel = ProEnvironmentViewModel()
    viewModel.selectTemplate(id: "proxy")
    XCTAssertEqual(viewModel.selectedTemplate?.id, "proxy")
    XCTAssertTrue(viewModel.templatePreview.contains("https_proxy"))
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --filter ProEnvironmentViewModelTests`
Expected: 编译失败，因为 ViewModel 不存在。

- [ ] **Step 3: 实现 ViewModel**

实现模板选择、诊断加载、GUI 变量草稿、项目目录选择状态、Keychain 草稿和命令执行结果。

- [ ] **Step 4: 验证通过**

Run: `swift test --filter ProEnvironmentViewModelTests`
Expected: PASS。

## Task 8: SwiftUI 页面接入

**Files:**
- Modify: `Sources/MacEnvCore/EnvironmentViewModel.swift`
- Modify: `Sources/MacEnvManager/ContentView.swift`
- Modify: `Sources/MacEnvManager/MacEnvManagerApp.swift`

- [ ] **Step 1: 扩展导航**

把 `AppSection` 扩展为 `variables/path/diagnostics/guiEnvironment/projects/wizard/secrets/backups/tools`，全部使用中文标题。

- [ ] **Step 2: 接入 Pro ViewModel**

在根视图创建或注入 `ProEnvironmentViewModel`，新增对应页面：

- 诊断：列表展示严重级别、标题、说明、建议。
- GUI 环境：输入变量名和值，生成 set/unset/get 命令，支持执行。
- 项目：选择项目目录、扫描 `.env`、显示重复键和缺失值。
- 向导：模板列表、变量/PATH/安装命令预览、执行安装命令。
- 密钥：输入变量名和值，生成 Keychain 保存/读取/删除命令。

- [ ] **Step 3: 运行构建**

Run: `swift build`
Expected: 编译通过。

## Task 9: README 和最终验证

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 更新中文 README**

补充诊断、GUI 环境、项目 `.env`、Keychain、模板向导、一键安装的使用说明，并注明分发能力仍未包含。

- [ ] **Step 2: 全量测试**

Run: `swift test`
Expected: 所有测试通过。

- [ ] **Step 3: 本地运行应用**

Run: `swift run MacEnvManager`
Expected: 应用能启动，新页面可见。

