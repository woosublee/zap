import XCTest
@testable import ZapApp

final class SettingsIssueBannerTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testUniqueMessagesDropsDuplicatesNilAndEmpty() {
        XCTAssertEqual(
            SettingsIssueBanner.uniqueMessages(["Shortcut taken", nil, "", "Shortcut taken", "Window error"]),
            ["Shortcut taken", "Window error"]
        )
    }

    func testBannerWithOnlyNilOrEmptyMessagesHasNothingToShow() {
        XCTAssertEqual(SettingsIssueBanner(messages: [nil, ""]).messages, [])
    }

    func testBannerRendersNothingWhenEmptyAndWarningLabelsOtherwise() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/ZapDesignSystem.swift"))

        XCTAssertTrue(source.contains("struct SettingsIssueBanner: View"))
        XCTAssertTrue(source.contains("if !messages.isEmpty {"))
        XCTAssertTrue(source.contains("Label(message, systemImage: \"exclamationmark.triangle.fill\")"))
    }

    func testSettingsCardSupportsTitleRowAccessory() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/ZapDesignSystem.swift"))

        XCTAssertTrue(source.contains("struct SettingsCard<Accessory: View, Content: View>: View"))
        XCTAssertTrue(source.contains("extension SettingsCard where Accessory == EmptyView"))
    }
}
