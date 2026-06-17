import XCTest
@testable import MacEnvCore

final class QuarantineRepairTests: XCTestCase {
    func testRepairPlanAcceptsAppBundleAndBuildsQuotedCommand() throws {
        let appURL = URL(fileURLWithPath: "/Applications/Mac Env Manager.app")

        let plan = try QuarantineRepairService().planRepair(for: appURL)

        XCTAssertEqual(plan.appPath, "/Applications/Mac Env Manager.app")
        XCTAssertEqual(plan.displayName, "Mac Env Manager.app")
        XCTAssertEqual(
            plan.terminalCommand,
            "sudo xattr -rd com.apple.quarantine '/Applications/Mac Env Manager.app'"
        )
        XCTAssertEqual(
            plan.appleScript,
            "do shell script \"xattr -rd com.apple.quarantine '/Applications/Mac Env Manager.app'\" with administrator privileges"
        )
    }

    func testRepairPlanRejectsNonAppPath() throws {
        let fileURL = URL(fileURLWithPath: "/Applications/README.txt")

        XCTAssertThrowsError(try QuarantineRepairService().planRepair(for: fileURL)) { error in
            XCTAssertEqual(error as? QuarantineRepairError, .notApplicationBundle("/Applications/README.txt"))
        }
    }

    func testRepairPlanQuotesSingleQuotesSafely() throws {
        let appURL = URL(fileURLWithPath: "/Applications/Bob's Tool.app")

        let plan = try QuarantineRepairService().planRepair(for: appURL)

        XCTAssertEqual(
            plan.terminalCommand,
            "sudo xattr -rd com.apple.quarantine '/Applications/Bob'\\''s Tool.app'"
        )
    }
}
