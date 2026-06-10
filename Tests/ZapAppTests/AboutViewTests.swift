import XCTest

final class AboutViewTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testAboutViewKeepsContentWithoutVisibleContainerStyling() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/AboutView.swift"))

        XCTAssertTrue(source.contains("presentation.appName"))
        XCTAssertTrue(source.contains("presentation.versionLine"))
        XCTAssertTrue(source.contains("presentation.creatorLine"))
        XCTAssertTrue(source.contains("foregroundStyle(.tint)"))
        XCTAssertFalse(source.contains(".regularMaterial"))
        XCTAssertFalse(source.contains("RoundedRectangle(cornerRadius: 18)"))
        XCTAssertFalse(source.contains("strokeBorder"))
    }

    func testAboutWindowPresenterUsesSharedAboutLayoutSize() throws {
        let viewSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/AboutView.swift"))
        let presenterSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Services/AboutWindowPresenter.swift"))

        XCTAssertTrue(viewSource.contains("static let contentWidth: CGFloat = 292"))
        XCTAssertTrue(viewSource.contains("static let windowHeight: CGFloat = 260"))
        XCTAssertTrue(viewSource.contains("frame(width: AboutLayout.contentWidth)"))
        XCTAssertTrue(presenterSource.contains("width: AboutLayout.contentWidth"))
        XCTAssertTrue(presenterSource.contains("height: AboutLayout.windowHeight"))
        XCTAssertFalse(viewSource.contains("frame(width: 292)"))
        XCTAssertFalse(presenterSource.contains("width: 292"))
    }
}
