import CoreGraphics
import XCTest
@testable import ZapApp
@testable import ZapCore

@MainActor
final class WindowManagementModelTests: XCTestCase {
    func testDisablingWindowManagementKeepsShortcutsButStopsActiveWindowHotkeys() {
        let model = makeModel()

        XCTAssertTrue(model.isWindowManagementEnabled)
        XCTAssertFalse(model.windowShortcuts.isEmpty)

        model.setWindowManagementEnabled(false)

        XCTAssertFalse(model.isWindowManagementEnabled)
        XCTAssertFalse(model.windowShortcuts.isEmpty)
        XCTAssertEqual(model.windowShortcutsForRegistration, [])
    }

    func testShortcutRecordingTemporarilyExcludesWindowHotkeysFromRegistration() {
        let model = makeModel()

        XCTAssertFalse(model.windowShortcutsForRegistration.isEmpty)

        model.setShortcutRecordingActive(true)

        XCTAssertTrue(model.isShortcutRecordingActive)
        XCTAssertFalse(model.windowShortcuts.isEmpty)
        XCTAssertEqual(model.windowShortcutsForRegistration, [])

        model.setShortcutRecordingActive(false)

        XCTAssertFalse(model.isShortcutRecordingActive)
        XCTAssertFalse(model.windowShortcutsForRegistration.isEmpty)
    }

    func testDisablingSingleWindowShortcutKeepsPresentationAndExcludesOnlyThatAction() throws {
        let model = makeModel()

        model.setShortcutEnabled(action: .leftHalf, isEnabled: false)

        let leftHalf = try XCTUnwrap(model.windowShortcuts.first { $0.action == .leftHalf })
        XCTAssertFalse(leftHalf.isEnabled)
        XCTAssertEqual(leftHalf.action.title, "Left Half")
        XCTAssertEqual(leftHalf.shortcutTitle, "⌥⌘←")
        XCTAssertFalse(model.windowShortcutsForRegistration.contains { $0.action == .leftHalf })
        XCTAssertTrue(model.windowShortcutsForRegistration.contains { $0.action == .rightHalf })
    }

    func testSetShortcutUpdatesPresentationAndReenablesAction() throws {
        let model = makeModel()

        model.setShortcutEnabled(action: .fullscreen, isEnabled: false)
        model.setShortcut(action: .fullscreen, keyCode: 3, keyDisplayName: "3", modifiers: [.control])

        let fullscreen = try XCTUnwrap(model.windowShortcuts.first { $0.action == .fullscreen })
        XCTAssertTrue(fullscreen.isEnabled)
        XCTAssertEqual(fullscreen.action.title, "Fullscreen")
        XCTAssertEqual(fullscreen.shortcutTitle, "⌃3")
        XCTAssertTrue(model.windowShortcutsForRegistration.contains { $0.action == .fullscreen })
    }

    func testResetWindowShortcutsRestoresSpectacleDefaultsAndEnablesActions() throws {
        let model = makeModel()

        model.setShortcut(action: .fullscreen, keyCode: 3, keyDisplayName: "3", modifiers: [.control])
        model.setShortcutEnabled(action: .fullscreen, isEnabled: false)

        model.resetShortcutsToDefaults()

        let fullscreen = try XCTUnwrap(model.windowShortcuts.first { $0.action == .fullscreen })
        XCTAssertTrue(fullscreen.isEnabled)
        XCTAssertEqual(fullscreen.shortcutTitle, "⌥⌘F")
        XCTAssertEqual(model.windowShortcutsForRegistration.count, WindowAction.allCases.count)
    }

    func testPermissionButtonsRequestPromptRefreshStateAndOpenSettings() {
        let permission = FakeAccessibilityPermission(isTrusted: false)
        let opener = FakeSystemSettingsOpener()
        let model = makeModel(permission: permission, settingsOpener: opener)

        XCTAssertFalse(model.accessibilityTrusted)

        model.requestAccessibilityPermission()
        XCTAssertEqual(permission.requestPromptCallCount, 1)

        permission.trusted = true
        model.refreshAccessibilityPermission()
        XCTAssertTrue(model.accessibilityTrusted)

        model.openAccessibilitySettings()
        XCTAssertEqual(opener.openSettingsCallCount, 1)
    }

    func testPerformUpdatesWindowManagementErrorForSettingsPresentation() {
        let service = FakeWindowActionPerformer(result: .failure(.focusedWindowMissing))
        let model = makeModel(service: service)

        _ = model.perform(action: .center)

        XCTAssertEqual(service.performedActions, [.center])
        XCTAssertEqual(model.windowManagementError, "focusedWindowMissing")
    }

    func testSetShortcutClearsStaleSheetWindowErrorFromRecorderAttempt() throws {
        let service = FakeWindowActionPerformer(result: .failure(.unsupportedWindow(.sheetOrSystemDialog)))
        let model = makeModel(service: service)

        _ = model.perform(action: .center)
        XCTAssertNotNil(model.windowManagementError)

        model.setShortcut(action: .center, keyCode: 0, keyDisplayName: "ㅁ", modifiers: [.control])

        let center = try XCTUnwrap(model.windowShortcuts.first { $0.action == .center })
        XCTAssertEqual(center.shortcutTitle, "⌃ㅁ")
        XCTAssertNil(model.windowManagementError)
        XCTAssertTrue(model.windowShortcutsForRegistration.contains { $0.action == .center })
    }

    func testWindowManagementEnabledIsPersistedInIsolatedUserDefaultsSuite() throws {
        let suiteName = "ZapAppTests.WindowManagementEnabled.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsWindowManagementSettingsStore(userDefaults: defaults)
        let firstModel = WindowManagementModel(
            service: FakeWindowActionPerformer(),
            permissionService: FakeAccessibilityPermission(isTrusted: true),
            settingsOpener: FakeSystemSettingsOpener(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: WindowShortcutDefaults.all),
            settingsStore: store
        )

        XCTAssertTrue(firstModel.isWindowManagementEnabled)

        firstModel.setWindowManagementEnabled(false)
        let reloadedModel = WindowManagementModel(
            service: FakeWindowActionPerformer(),
            permissionService: FakeAccessibilityPermission(isTrusted: true),
            settingsOpener: FakeSystemSettingsOpener(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: WindowShortcutDefaults.all),
            settingsStore: UserDefaultsWindowManagementSettingsStore(userDefaults: defaults)
        )

        XCTAssertFalse(reloadedModel.isWindowManagementEnabled)
    }

    private func makeModel(
        service: FakeWindowActionPerformer = FakeWindowActionPerformer(),
        permission: FakeAccessibilityPermission = FakeAccessibilityPermission(isTrusted: true),
        settingsOpener: FakeSystemSettingsOpener = FakeSystemSettingsOpener(),
        shortcuts: [WindowShortcut] = WindowShortcutDefaults.all,
        isEnabled: Bool = true
    ) -> WindowManagementModel {
        WindowManagementModel(
            service: service,
            permissionService: permission,
            settingsOpener: settingsOpener,
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: shortcuts),
            isWindowManagementEnabled: isEnabled
        )
    }
}

private final class FakeWindowActionPerformer: WindowActionPerforming {
    var performedActions: [WindowAction] = []
    var result: WindowManagementResult

    init(result: WindowManagementResult = .success(action: .leftHalf, frame: CGRect(x: 0, y: 0, width: 100, height: 100))) {
        self.result = result
    }

    func perform(action: WindowAction) -> WindowManagementResult {
        performedActions.append(action)
        return result
    }
}

private final class FakeAccessibilityPermission: AccessibilityPermissionChecking {
    var trusted: Bool
    var requestPromptCallCount = 0

    init(isTrusted: Bool) {
        trusted = isTrusted
    }

    var isTrusted: Bool { trusted }

    func requestPrompt() {
        requestPromptCallCount += 1
    }
}

private final class FakeSystemSettingsOpener: SystemSettingsOpening {
    var openSettingsCallCount = 0
    var result = true

    func openAccessibilitySettings() -> Bool {
        openSettingsCallCount += 1
        return result
    }
}

private final class InMemoryWindowShortcutStore: WindowShortcutStoring {
    var shortcuts: [WindowShortcut]
    var savedShortcuts: [[WindowShortcut]] = []

    init(shortcuts: [WindowShortcut]) {
        self.shortcuts = shortcuts
    }

    func loadWindowShortcuts() -> [WindowShortcut] {
        shortcuts
    }

    func saveWindowShortcuts(_ shortcuts: [WindowShortcut]) {
        self.shortcuts = shortcuts
        savedShortcuts.append(shortcuts)
    }
}
