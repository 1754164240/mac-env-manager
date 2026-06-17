import MacEnvCore
import XCTest

@MainActor
final class ProEnvironmentViewModelTests: XCTestCase {
    func testViewModelSelectsTemplateAndBuildsInstallPreview() {
        let viewModel = ProEnvironmentViewModel()

        viewModel.selectTemplate(id: "proxy")

        XCTAssertEqual(viewModel.selectedTemplate?.id, "proxy")
        XCTAssertTrue(viewModel.templatePreview.contains("https_proxy"))
    }

    func testViewModelBuildsGuiEnvironmentPlans() {
        let viewModel = ProEnvironmentViewModel()
        viewModel.guiVariableName = "HTTP_PROXY"
        viewModel.guiVariableValue = "http://127.0.0.1:7897"

        viewModel.buildGUISetPlan()

        XCTAssertEqual(viewModel.pendingGUIPlan?.arguments, ["setenv", "HTTP_PROXY", "http://127.0.0.1:7897"])
        XCTAssertTrue(viewModel.pendingGUICommandPreview.contains("launchctl setenv HTTP_PROXY"))
    }

    func testViewModelReadsGuiEnvironmentValueIntoDraft() {
        let viewModel = ProEnvironmentViewModel(
            commandRunner: FakeSingleResultRunner(result: CommandResult.fixture(stdout: "from-launchd\n", exitCode: 0))
        )
        viewModel.guiVariableName = "HTTP_PROXY"
        viewModel.buildGUIGetPlan()

        viewModel.runPendingGUIPlan()

        XCTAssertEqual(viewModel.guiVariableValue, "from-launchd")
        XCTAssertEqual(viewModel.guiVariables, [GUIEnvironmentVariable(name: "HTTP_PROXY", value: "from-launchd")])
    }

    func testViewModelScansProjectEnvironmentFiles() throws {
        let root = try TemporaryHome()
        try root.write(".env", "API_URL=https://example.com\n")
        let viewModel = ProEnvironmentViewModel()

        try viewModel.scanProject(at: root.url)

        XCTAssertEqual(viewModel.projectSnapshot?.variables.first?.key, "API_URL")
    }

    func testViewModelPlansAndAppliesProjectEnvChange() throws {
        let root = try TemporaryHome()
        try root.write(".env", "API_URL=https://old.example.com\n")
        let viewModel = ProEnvironmentViewModel()
        try viewModel.scanProject(at: root.url)

        viewModel.projectVariableKey = "API_URL"
        viewModel.projectVariableValue = "https://new.example.com"
        try viewModel.planProjectEnvWrite()
        try viewModel.applyProjectEnvWrite()

        let updated = try String(contentsOfFile: root.path(".env"), encoding: .utf8)
        XCTAssertTrue(updated.contains("API_URL='https://new.example.com'"))
        XCTAssertNotNil(viewModel.projectSnapshot?.variables.first { $0.value == "https://new.example.com" })
    }

    func testViewModelCanTargetEnvLocalWhenPlanningProjectWrite() throws {
        let root = try TemporaryHome()
        try root.write(".env.local", "TOKEN=old\n")
        let viewModel = ProEnvironmentViewModel()
        try viewModel.scanProject(at: root.url)
        viewModel.selectedProjectEnvFileName = ".env.local"
        viewModel.projectVariableKey = "TOKEN"
        viewModel.projectVariableValue = "new"

        try viewModel.planProjectEnvWrite()

        XCTAssertEqual(viewModel.pendingProjectChange?.path, root.path(".env.local"))
        XCTAssertTrue(viewModel.pendingProjectChange?.updated.contains("TOKEN='new'") == true)
    }

    func testViewModelSelectsProjectVariableIntoDraft() throws {
        let root = try TemporaryHome()
        try root.write(".env", "API_URL=https://example.com\nTOKEN=abc\n")
        let viewModel = ProEnvironmentViewModel()
        try viewModel.scanProject(at: root.url)
        let token = try XCTUnwrap(viewModel.projectSnapshot?.variables.first { $0.key == "TOKEN" })

        viewModel.selectProjectVariable(id: token.id)

        XCTAssertEqual(viewModel.projectVariableKey, "TOKEN")
        XCTAssertEqual(viewModel.projectVariableValue, "abc")
    }

    func testViewModelBuildsKeychainSavePlanAndSnippet() {
        let viewModel = ProEnvironmentViewModel()
        viewModel.secretName = "OPENAI_API_KEY"
        viewModel.secretValue = "secret"

        viewModel.buildKeychainSavePlan()

        XCTAssertEqual(viewModel.pendingKeychainPlan?.arguments.last, "secret")
        XCTAssertTrue(viewModel.keychainShellSnippet.contains("OPENAI_API_KEY"))
    }

    func testViewModelAppliesTemplateToEnvironmentSnapshot() {
        let viewModel = ProEnvironmentViewModel()
        viewModel.selectTemplate(id: "proxy")
        var snapshot = EnvironmentSnapshot()

        viewModel.applySelectedTemplate(to: &snapshot)

        XCTAssertTrue(snapshot.variables.contains { $0.name == "https_proxy" && $0.source == .managed })
        XCTAssertTrue(snapshot.variables.contains { $0.name == "all_proxy" && $0.value.contains("socks5") })
    }
}

private struct FakeSingleResultRunner: CommandRunning {
    var result: CommandResult

    func run(_ plan: CommandPlan) throws -> CommandResult {
        CommandResult(
            plan: plan,
            stdout: result.stdout,
            stderr: result.stderr,
            exitCode: result.exitCode,
            startedAt: result.startedAt,
            finishedAt: result.finishedAt
        )
    }
}

private extension CommandResult {
    static func fixture(stdout: String = "", stderr: String = "", exitCode: Int32) -> CommandResult {
        CommandResult(
            plan: CommandPlan(title: "fixture", executable: "/bin/launchctl"),
            stdout: stdout,
            stderr: stderr,
            exitCode: exitCode,
            startedAt: Date(timeIntervalSince1970: 0),
            finishedAt: Date(timeIntervalSince1970: 1)
        )
    }
}
