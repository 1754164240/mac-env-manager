import XCTest
@testable import MacEnvCore

final class ShellParserTests: XCTestCase {
    func testParsesSimpleExportsAndAssignments() throws {
        let content = """
        # user comment
        export JAVA_HOME="/Library/Java/Home"
        ANDROID_HOME=$HOME/Library/Android/sdk
        export OPENAI_API_KEY='sk-proj-example'
        export COMPLEX="$(brew --prefix)/bin"
        """

        let result = ShellParser().parse(content: content, sourcePath: "~/.zshrc")

        XCTAssertEqual(result.definitions.map(\.name), ["JAVA_HOME", "ANDROID_HOME", "OPENAI_API_KEY"])
        XCTAssertEqual(result.definitions.map(\.value), ["/Library/Java/Home", "$HOME/Library/Android/sdk", "sk-proj-example"])
        XCTAssertEqual(result.definitions.map(\.isExported), [true, false, true])
        XCTAssertEqual(result.unmanagedLines.map(\.lineNumber), [5])
    }

    func testParsesToolBlocksSeparatelyFromImportableDefinitions() throws {
        let content = """
        export KEEP_THIS=manual
        # >>> Mac Env Manager
        export JAVA_HOME='/Library/Java/Home'
        export DISABLED_VALUE='off' # mac-env-disabled
        # <<< Mac Env Manager
        """

        let result = ShellParser().parse(content: content, sourcePath: "~/.zshrc")

        XCTAssertEqual(result.importableDefinitions.map(\.name), ["KEEP_THIS"])
        XCTAssertEqual(result.managedDefinitions.map(\.name), ["JAVA_HOME", "DISABLED_VALUE"])
        XCTAssertEqual(result.managedDefinitions.map(\.isEnabled), [true, false])
    }

    func testParsesPathIntoStructuredEntries() throws {
        let content = """
        export PATH="/usr/local/bin:$HOME/bin:/usr/local/bin:/missing/tool:$PATH"
        """

        let result = ShellParser().parse(content: content, sourcePath: "~/.zprofile")
        let entries = try XCTUnwrap(result.pathDefinition?.entries)

        XCTAssertEqual(entries.map(\.value), ["/usr/local/bin", "$HOME/bin", "/usr/local/bin", "/missing/tool"])
        XCTAssertEqual(entries.map(\.isDuplicate), [false, false, true, false])
        XCTAssertTrue(result.pathDefinition?.preservesExistingPath == true)
    }

    func testParsesEveryPathSettingWithSourceLineMetadata() throws {
        let content = """
        export FIRST=one
        export PATH="/usr/local/bin:$PATH"
        # comment
        PATH="$HOME/bin:/opt/tools:$PATH"
        """

        let result = ShellParser().parse(content: content, sourcePath: "/tmp/home/.zshrc")

        XCTAssertEqual(result.pathDefinitions.count, 2)
        XCTAssertEqual(result.pathDefinitions.map(\.lineNumber), [2, 4])
        XCTAssertEqual(result.pathDefinitions.map(\.rawLine), [
            "export PATH=\"/usr/local/bin:$PATH\"",
            "PATH=\"$HOME/bin:/opt/tools:$PATH\""
        ])
        XCTAssertEqual(result.pathDefinitions.flatMap(\.entries).map(\.value), [
            "/usr/local/bin",
            "$HOME/bin",
            "/opt/tools"
        ])
        XCTAssertEqual(result.pathDefinitions.flatMap(\.entries).map(\.sourcePath), [
            "/tmp/home/.zshrc",
            "/tmp/home/.zshrc",
            "/tmp/home/.zshrc"
        ])
        XCTAssertEqual(result.pathDefinitions.flatMap(\.entries).map(\.lineNumber), [2, 4, 4])
    }
}
