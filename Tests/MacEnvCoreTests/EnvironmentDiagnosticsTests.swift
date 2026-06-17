import MacEnvCore
import XCTest

final class EnvironmentDiagnosticsTests: XCTestCase {
    func testDiagnosticsReportMissingPathProxyGroupAndSensitivePlaintext() {
        let snapshot = EnvironmentSnapshot(
            variables: [
                EnvVariable(name: "API_TOKEN", value: "plain", source: .managed),
                EnvVariable(name: "http_proxy", value: "http://127.0.0.1:7897", source: .managed)
            ],
            pathEntries: [
                PathEntry(value: "/missing", existsOnDisk: false),
                PathEntry(value: "/usr/bin", isDuplicate: true)
            ]
        )

        let diagnostics = EnvironmentDiagnosticsService().diagnose(snapshot: snapshot, guiVariables: [], toolChecks: [])

        XCTAssertTrue(diagnostics.contains { $0.title.contains("PATH 不存在") })
        XCTAssertTrue(diagnostics.contains { $0.title.contains("PATH 重复") })
        XCTAssertTrue(diagnostics.contains { $0.title.contains("代理变量不完整") })
        XCTAssertTrue(diagnostics.contains { $0.title.contains("疑似敏感变量") })
    }

    func testDiagnosticsReportShellAndGuiValueMismatch() {
        let snapshot = EnvironmentSnapshot(
            variables: [EnvVariable(name: "JAVA_HOME", value: "/shell/java", source: .managed)]
        )
        let gui = [GUIEnvironmentVariable(name: "JAVA_HOME", value: "/gui/java")]

        let diagnostics = EnvironmentDiagnosticsService().diagnose(snapshot: snapshot, guiVariables: gui, toolChecks: [])

        XCTAssertTrue(diagnostics.contains { $0.title.contains("GUI 环境不一致") })
    }

    func testDiagnosticsReportProjectDuplicateAndEmptyValues() {
        let project = ProjectEnvSnapshot(
            projectDirectory: "/tmp/app",
            variables: [
                ProjectEnvVariable(key: "TOKEN", value: "abc", fileName: ".env", filePath: "/tmp/app/.env", lineNumber: 1),
                ProjectEnvVariable(key: "TOKEN", value: "override", fileName: ".env.local", filePath: "/tmp/app/.env.local", lineNumber: 1, isDuplicate: true),
                ProjectEnvVariable(key: "EMPTY", value: "", fileName: ".env", filePath: "/tmp/app/.env", lineNumber: 2)
            ]
        )

        let diagnostics = EnvironmentDiagnosticsService().diagnose(snapshot: EnvironmentSnapshot(), guiVariables: [], toolChecks: [], projectSnapshot: project)

        XCTAssertTrue(diagnostics.contains { $0.title.contains("项目变量重复") })
        XCTAssertTrue(diagnostics.contains { $0.title.contains("项目变量为空") })
    }
}
