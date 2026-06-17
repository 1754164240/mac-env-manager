import MacEnvCore
import XCTest

final class KeychainSecretStoreTests: XCTestCase {
    func testSavePlanUsesSecurityAddGenericPassword() {
        let store = KeychainSecretStore()

        let plan = store.savePlan(account: "OPENAI_API_KEY", value: "secret")

        XCTAssertEqual(plan.executable, "/usr/bin/security")
        XCTAssertEqual(plan.arguments, ["add-generic-password", "-U", "-s", "Mac Env Manager", "-a", "OPENAI_API_KEY", "-w", "secret"])
    }

    func testReadShellSnippetUsesSecurityFindGenericPassword() {
        let store = KeychainSecretStore()

        let snippet = store.shellSnippet(account: "OPENAI_API_KEY")

        XCTAssertEqual(snippet, "export OPENAI_API_KEY=$(security find-generic-password -s 'Mac Env Manager' -a 'OPENAI_API_KEY' -w)")
    }
}

