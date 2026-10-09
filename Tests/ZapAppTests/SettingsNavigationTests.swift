import XCTest
@testable import ZapApp

final class SettingsNavigationTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "SettingsNavigationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    func testSettingsModesAreGeneralAppsWindowsInOrder() {
        XCTAssertEqual(SettingsMode.allCases.map(\.title), ["General", "Apps", "Windows"])
        XCTAssertEqual(SettingsMode.allCases.map(\.systemImage), ["gearshape", "square.grid.2x2", "rectangle.3.group"])
    }

    func testInitialModeDefaultsToGeneral() {
        XCTAssertEqual(SettingsMode.initial(requested: nil, storedRawValue: nil), .general)
    }

    func testInitialModeUsesStoredLastMode() {
        XCTAssertEqual(SettingsMode.initial(requested: nil, storedRawValue: "windows"), .windows)
    }

    func testInitialModePrefersRequestedModeOverStoredMode() {
        XCTAssertEqual(SettingsMode.initial(requested: .apps, storedRawValue: "windows"), .apps)
    }

    func testInitialModeFallsBackToGeneralForUnknownStoredValue() {
        for stale in ["automatic", "manual", "windowManagement", "about", ""] {
            XCTAssertEqual(SettingsMode.initial(requested: nil, storedRawValue: stale), .general, stale)
        }
    }

    func testSelectingModePersistsLastMode() {
        let defaults = makeDefaults()
        let state = SettingsNavigationState(selectedMode: .general, defaults: defaults)

        XCTAssertNil(defaults.string(forKey: SettingsMode.lastModeDefaultsKey))

        state.selectedMode = .windows

        XCTAssertEqual(defaults.string(forKey: SettingsMode.lastModeDefaultsKey), "windows")
    }
}
