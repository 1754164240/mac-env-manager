import MacEnvCore
import XCTest

final class EnvironmentTemplateCatalogTests: XCTestCase {
    func testCatalogContainsRequiredTemplatesAndProxyVariables() {
        let catalog = EnvironmentTemplateCatalog.defaultCatalog()

        XCTAssertEqual(
            Set(catalog.templates.map(\.id)),
            Set(["homebrew", "node", "python", "java", "android", "go", "rust", "proxy"])
        )
        let proxy = catalog.templates.first { $0.id == "proxy" }
        XCTAssertTrue(proxy?.variables.contains { $0.name == "https_proxy" } == true)
        XCTAssertTrue(catalog.templates.contains { $0.installCommands.isEmpty == false })
    }

    func testTemplatePreviewContainsVariablesPathAndInstallCommands() throws {
        let catalog = EnvironmentTemplateCatalog.defaultCatalog()
        let android = try XCTUnwrap(catalog.templates.first { $0.id == "android" })

        let preview = catalog.preview(for: android)

        XCTAssertTrue(preview.contains("ANDROID_HOME"))
        XCTAssertTrue(preview.contains("platform-tools"))
        XCTAssertTrue(preview.contains("brew install --cask android-platform-tools"))
    }
}
