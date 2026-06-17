import MacEnvCore
import XCTest

final class ToolCheckServiceTests: XCTestCase {
    func testToolCheckerMarksAvailableCommandWithResolvedPath() throws {
        let checker = ToolCheckService(runner: FakeCommandRunner(results: [
            "command -v node": CommandResult.fixture(stdout: "/opt/homebrew/bin/node\n", exitCode: 0)
        ]))

        let results = checker.check(commands: ["node"])

        XCTAssertEqual(results, [ToolCheckResult(command: "node", isAvailable: true, resolvedPath: "/opt/homebrew/bin/node")])
    }

    func testToolCheckerMarksMissingCommand() throws {
        let checker = ToolCheckService(runner: FakeCommandRunner(results: [
            "command -v adb": CommandResult.fixture(stderr: "not found\n", exitCode: 1)
        ]))

        let results = checker.check(commands: ["adb"])

        XCTAssertEqual(results, [ToolCheckResult(command: "adb", isAvailable: false, resolvedPath: nil)])
    }
}

private struct FakeCommandRunner: CommandRunning {
    var results: [String: CommandResult]

    func run(_ plan: CommandPlan) throws -> CommandResult {
        let key = plan.arguments.last ?? plan.previewCommand
        return results[key] ?? CommandResult.fixture(exitCode: 127)
    }
}

private extension CommandResult {
    static func fixture(stdout: String = "", stderr: String = "", exitCode: Int32) -> CommandResult {
        CommandResult(
            plan: CommandPlan(title: "fixture", executable: "/bin/zsh", arguments: []),
            stdout: stdout,
            stderr: stderr,
            exitCode: exitCode,
            startedAt: Date(timeIntervalSince1970: 0),
            finishedAt: Date(timeIntervalSince1970: 1)
        )
    }
}

