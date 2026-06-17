import MacEnvCore
import XCTest

final class ProjectEnvServiceTests: XCTestCase {
    func testScannerReadsEnvFilesAndReportsDuplicates() throws {
        let root = try TemporaryHome()
        try root.write(".env", "API_URL=https://example.com\nTOKEN=abc\n")
        try root.write(".env.local", "TOKEN=override\nEMPTY=\n")
        let scanner = ProjectEnvScanner(projectDirectory: root.url)

        let snapshot = try scanner.scan()

        XCTAssertEqual(snapshot.files.map(\.name).sorted(), [".env", ".env.local"])
        XCTAssertTrue(snapshot.variables.contains { $0.key == "TOKEN" && $0.isDuplicate })
        XCTAssertTrue(snapshot.variables.contains { $0.key == "EMPTY" && $0.value.isEmpty })
    }

    func testDirenvContentUsesDotenvForEnvFile() {
        let writer = ProjectEnvWriter(projectDirectory: URL(fileURLWithPath: "/tmp/project"))

        XCTAssertEqual(writer.direnvContent(forEnvFile: ".env"), "dotenv .env\n")
    }

    func testWriterPlansEnvFileChangeWithBackupDirectory() throws {
        let root = try TemporaryHome()
        try root.write(".env", "API_URL=https://old.example.com\n")
        let writer = ProjectEnvWriter(projectDirectory: root.url)

        let change = try writer.planWrite(
            fileName: ".env",
            variables: [ProjectEnvVariable(key: "API_URL", value: "https://new.example.com", fileName: ".env", filePath: root.path(".env"), lineNumber: 1)]
        )

        XCTAssertEqual(change.path, root.path(".env"))
        XCTAssertTrue(change.updated.contains("API_URL='https://new.example.com'"))
        XCTAssertTrue(change.diff.contains("- API_URL=https://old.example.com"))
        XCTAssertEqual(writer.backupsDirectory.path, root.path(".mac-env-manager/backups"))
    }
}
