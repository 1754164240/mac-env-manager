import XCTest
@testable import MacEnvCore

final class ShellGenerationTests: XCTestCase {
    func testGeneratesQuotedManagedShellBlock() throws {
        let variables = [
            EnvVariable(name: "JAVA_HOME", value: "/Library/Java/Home", isExported: true, isEnabled: true, source: .managed),
            EnvVariable(name: "LOCAL_ONLY", value: "hello world", isExported: false, isEnabled: true, source: .managed),
            EnvVariable(name: "DISABLED", value: "off", isExported: true, isEnabled: false, source: .managed)
        ]

        let block = ShellGenerator().managedBlock(variables: variables, pathEntries: [])

        XCTAssertTrue(block.contains("# >>> Mac Env Manager"))
        XCTAssertTrue(block.contains("export JAVA_HOME='/Library/Java/Home'"))
        XCTAssertTrue(block.contains("LOCAL_ONLY='hello world'"))
        XCTAssertTrue(block.contains("# export DISABLED='off' # mac-env-disabled"))
        XCTAssertTrue(block.contains("# <<< Mac Env Manager"))
    }

    func testGeneratesKeychainReferenceWithoutSingleQuotingCommandSubstitution() throws {
        let variables = [
            EnvVariable(name: "OPENAI_API_KEY", value: "$(security find-generic-password -s 'Mac Env Manager' -a 'OPENAI_API_KEY' -w)", source: .managed)
        ]

        let block = ShellGenerator().managedBlock(variables: variables, pathEntries: [])

        XCTAssertTrue(block.contains("export OPENAI_API_KEY=$(security find-generic-password -s 'Mac Env Manager' -a 'OPENAI_API_KEY' -w)"))
        XCTAssertFalse(block.contains("OPENAI_API_KEY='$(security"))
    }

    func testGeneratesStructuredPathWithoutDuplicateEnabledEntries() throws {
        let pathEntries = [
            PathEntry(value: "/usr/local/bin", isEnabled: true),
            PathEntry(value: "$HOME/bin", isEnabled: true),
            PathEntry(value: "/usr/local/bin", isEnabled: true),
            PathEntry(value: "/disabled/bin", isEnabled: false)
        ]

        let block = ShellGenerator().managedBlock(variables: [], pathEntries: pathEntries)

        XCTAssertTrue(block.contains("export PATH='/usr/local/bin:$HOME/bin':$PATH"))
        XCTAssertTrue(block.contains("# PATH entry disabled: /disabled/bin"))
        XCTAssertFalse(block.contains("/usr/local/bin:/usr/local/bin"))
    }

    func testPathGenerationSkipsDuplicateDisabledComments() throws {
        let pathEntries = [
            PathEntry(value: "$HOME/.local/bin", isEnabled: true),
            PathEntry(value: "$HOME/.local/bin", isEnabled: true, isDuplicate: true),
            PathEntry(value: "$HOME/.local/bin", isEnabled: true, isDuplicate: true)
        ]

        let block = ShellGenerator().managedBlock(variables: [], pathEntries: pathEntries)

        XCTAssertEqual(block.components(separatedBy: "$HOME/.local/bin").count - 1, 1)
        XCTAssertFalse(block.contains("PATH entry disabled"))
    }
}
