import XCTest

final class AboutViewTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testAboutViewKeepsContentAndUsesRefinedNativeCardStyling() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/AboutView.swift"))

        XCTAssertTrue(source.contains("presentation.appName"))
        XCTAssertTrue(source.contains("presentation.versionLine"))
        XCTAssertTrue(source.contains("presentation.creatorLine"))
        XCTAssertTrue(source.contains(".regularMaterial"))
        XCTAssertTrue(source.contains("RoundedRectangle(cornerRadius: 18"))
        XCTAssertTrue(source.contains("foregroundStyle(.tint)"))
    }

    func testAboutWindowPresenterMatchesRedesignedAboutViewWidth() throws {
        let viewSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/AboutView.swift"))
        let presenterSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Services/AboutWindowPresenter.swift"))

        XCTAssertTrue(viewSource.contains("frame(width: 292)"))
        XCTAssertTrue(presenterSource.contains("width: 292"))
    }
}
