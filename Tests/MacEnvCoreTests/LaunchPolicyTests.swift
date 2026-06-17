import XCTest
@testable import MacEnvCore

final class LaunchPolicyTests: XCTestCase {
    func testLaunchPolicyRequestsRegularForegroundActivation() {
        let policy = LaunchPolicy()

        XCTAssertEqual(policy.activationPolicy, .regular)
        XCTAssertTrue(policy.activatesIgnoringOtherApps)
    }
}
