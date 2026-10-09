import XCTest
@testable import ZapApp

final class AppDistributionTests: XCTestCase {
    func testOnlyDirectDistributionSupportsInAppUpdates() {
        XCTAssertTrue(AppDistribution.direct.supportsInAppUpdates)
        XCTAssertFalse(AppDistribution.appStore.supportsInAppUpdates)
    }

    func testDefaultBuildIsDirectDistribution() {
        XCTAssertEqual(AppDistribution.current, .direct)
    }
}
