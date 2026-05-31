import XCTest
@testable import ZapApp

@MainActor
final class UpdateServiceTests: XCTestCase {
    func testAutomaticChecksAreAllowedOnlyForSemanticReleaseBuildTags() {
        XCTAssertTrue(UpdateService.isReleaseBuildTagForAutomaticChecks("v0.1.2"))
        XCTAssertTrue(UpdateService.isReleaseBuildTagForAutomaticChecks("V1.2.3"))
        XCTAssertTrue(UpdateService.isReleaseBuildTagForAutomaticChecks("v1.2.3-beta.1"))

        XCTAssertFalse(UpdateService.isReleaseBuildTagForAutomaticChecks(nil))
        XCTAssertFalse(UpdateService.isReleaseBuildTagForAutomaticChecks(""))
        XCTAssertFalse(UpdateService.isReleaseBuildTagForAutomaticChecks("0.1.2"))
        XCTAssertFalse(UpdateService.isReleaseBuildTagForAutomaticChecks("local-abc123"))
        XCTAssertFalse(UpdateService.isReleaseBuildTagForAutomaticChecks("dev-0.1.2"))
        XCTAssertFalse(UpdateService.isReleaseBuildTagForAutomaticChecks("v1"))
        XCTAssertFalse(UpdateService.isReleaseBuildTagForAutomaticChecks("v1.2"))
    }

    func testStartDoesNotStartUpdaterForLocalBuilds() {
        let driver = FakeUpdateDriver()
        let service = UpdateService(
            driverFactory: { driver },
            buildTagProvider: { "local-abc123" }
        )

        service.start()

        XCTAssertEqual(driver.startCallCount, 0)
    }

    func testStartStartsUpdaterForReleaseBuilds() {
        let driver = FakeUpdateDriver()
        let service = UpdateService(
            driverFactory: { driver },
            buildTagProvider: { "v0.1.2" }
        )

        service.start()

        XCTAssertEqual(driver.startCallCount, 1)
    }

    func testStartIsIdempotent() {
        let driver = FakeUpdateDriver()
        let service = UpdateService(
            driverFactory: { driver },
            buildTagProvider: { "v0.1.2" }
        )

        service.start()
        service.start()

        XCTAssertEqual(driver.startCallCount, 1)
    }

    func testManualCheckStartsUpdaterAndForwardsCheck() {
        let driver = FakeUpdateDriver()
        let service = UpdateService(
            driverFactory: { driver },
            buildTagProvider: { "local-abc123" }
        )

        service.checkForUpdates()

        XCTAssertEqual(driver.startCallCount, 1)
        XCTAssertEqual(driver.checkForUpdatesCallCount, 1)
    }

    func testCanCheckForUpdatesReadsDriver() {
        let driver = FakeUpdateDriver()
        driver.canCheckForUpdates = false
        let service = UpdateService(
            driverFactory: { driver },
            buildTagProvider: { "v0.1.2" }
        )

        XCTAssertFalse(service.canCheckForUpdates)
    }

    func testAutomaticCheckPreferenceReadsAndWritesDriver() {
        let driver = FakeUpdateDriver()
        driver.automaticallyChecksForUpdates = false
        let service = UpdateService(
            driverFactory: { driver },
            buildTagProvider: { "v0.1.2" }
        )

        XCTAssertFalse(service.automaticallyChecksForUpdates)

        service.automaticallyChecksForUpdates = true

        XCTAssertTrue(driver.automaticallyChecksForUpdates)
    }
}

@MainActor
private final class FakeUpdateDriver: UpdateDriving {
    var automaticallyChecksForUpdates = true
    var canCheckForUpdates = true
    private(set) var startCallCount = 0
    private(set) var checkForUpdatesCallCount = 0

    func start() {
        startCallCount += 1
    }

    func checkForUpdates() {
        checkForUpdatesCallCount += 1
    }
}
