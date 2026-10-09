import XCTest

final class ReadmeSettingsTests: XCTestCase {
    private var readme: String {
        get throws {
            try String(contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("README.md"))
        }
    }

    func testReadmeDescribesGeneralAppsWindowsSettingsPages() throws {
        let source = try readme
        let settingsStart = try XCTUnwrap(source.range(of: "## Settings\n"))
        let settingsEnd = try XCTUnwrap(source.range(of: "## Privacy and permissions", range: settingsStart.upperBound..<source.endIndex))
        let settings = String(source[settingsStart.upperBound..<settingsEnd.lowerBound])

        XCTAssertTrue(settings.contains("### General"))
        XCTAssertTrue(settings.contains("### Apps"))
        XCTAssertTrue(settings.contains("### Windows"))
        XCTAssertFalse(settings.contains("### Automatic"))
        XCTAssertFalse(settings.contains("### Manual"))
        XCTAssertFalse(settings.contains("### Window Management"))
        XCTAssertFalse(settings.contains("### About"))
    }

    func testReadmeMenuBarListIncludesAboutZap() throws {
        XCTAssertTrue(try readme.contains("- About Zap;\n- Settings;"))
    }
}
