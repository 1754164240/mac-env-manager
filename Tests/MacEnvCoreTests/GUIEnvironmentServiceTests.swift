import MacEnvCore
import XCTest

final class GUIEnvironmentServiceTests: XCTestCase {
    func testSetenvPlanQuotesValueAndUsesLaunchctl() {
        let service = GUIEnvironmentService()

        let plan = service.setPlan(name: "HTTP_PROXY", value: "http://127.0.0.1:7897")

        XCTAssertEqual(plan.executable, "/bin/launchctl")
        XCTAssertEqual(plan.arguments, ["setenv", "HTTP_PROXY", "http://127.0.0.1:7897"])
        XCTAssertEqual(plan.previewCommand, "launchctl setenv HTTP_PROXY 'http://127.0.0.1:7897'")
    }

    func testUnsetPlanUsesLaunchctlUnsetenv() {
        let service = GUIEnvironmentService()

        let plan = service.unsetPlan(name: "HTTP_PROXY")

        XCTAssertEqual(plan.executable, "/bin/launchctl")
        XCTAssertEqual(plan.arguments, ["unsetenv", "HTTP_PROXY"])
        XCTAssertEqual(plan.previewCommand, "launchctl unsetenv HTTP_PROXY")
    }

    func testParseGetenvResultTrimsTrailingNewline() {
        let service = GUIEnvironmentService()
        let result = CommandResult(
            plan: service.getPlan(name: "HTTP_PROXY"),
            stdout: "http://127.0.0.1:7897\n",
            stderr: "",
            exitCode: 0,
            startedAt: Date(),
            finishedAt: Date()
        )

        XCTAssertEqual(service.parseGetenvResult(result), "http://127.0.0.1:7897")
    }
}

