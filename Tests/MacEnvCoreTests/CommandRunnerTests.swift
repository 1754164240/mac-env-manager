import MacEnvCore
import XCTest

final class CommandRunnerTests: XCTestCase {
    func testShellCommandRunnerCapturesOutputAndExitCode() throws {
        let runner = ShellCommandRunner()

        let result = try runner.run(CommandPlan(title: "echo", executable: "/bin/sh", arguments: ["-c", "printf hello"]))

        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, "hello")
        XCTAssertEqual(result.stderr, "")
        XCTAssertEqual(result.plan.previewCommand, "/bin/sh -c 'printf hello'")
    }

    func testShellCommandRunnerCapturesStderrForFailure() throws {
        let runner = ShellCommandRunner()

        let result = try runner.run(CommandPlan(title: "failure", executable: "/bin/sh", arguments: ["-c", "printf problem >&2; exit 7"]))

        XCTAssertEqual(result.exitCode, 7)
        XCTAssertEqual(result.stdout, "")
        XCTAssertEqual(result.stderr, "problem")
    }
}

