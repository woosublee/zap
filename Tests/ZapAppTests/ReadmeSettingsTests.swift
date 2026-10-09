import XCTest

final class ReadmeSettingsTests: XCTestCase {
    private static let readmeFileNames = ["README.md", "README.en.md"]

    private func readme(_ fileName: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(fileName))
    }

    func testReadmesPointToGeneralAppsWindowsSettingsPages() throws {
        for fileName in Self.readmeFileNames {
            let source = try readme(fileName)

            XCTAssertTrue(source.contains("**Settings > General**") || source.contains("**설정 > General**"), fileName)
            XCTAssertTrue(source.contains("**Settings > Apps**") || source.contains("**설정 > Apps**"), fileName)
            XCTAssertTrue(source.contains("**Settings > Windows**") || source.contains("**설정 > Windows**"), fileName)
            XCTAssertFalse(source.contains("> Automatic"), fileName)
            XCTAssertFalse(source.contains("> Manual"), fileName)
            XCTAssertFalse(source.contains("> Window Management"), fileName)
            XCTAssertFalse(source.contains("> About"), fileName)
        }
    }

    func testReadmeMenuBarListIncludesAboutZap() throws {
        XCTAssertTrue(try readme("README.md").contains("Zap 정보, 설정, 종료"))
        XCTAssertTrue(try readme("README.en.md").contains("About Zap, Settings, and Quit"))
    }

    func testReadmePermissionTextPointsToWindowsGrantButton() throws {
        for fileName in Self.readmeFileNames {
            let source = try readme(fileName)

            XCTAssertFalse(source.contains("Zap shows the permission state in Settings"), fileName)
            XCTAssertTrue(source.contains("**Grant…**"), fileName)
        }
    }
}
