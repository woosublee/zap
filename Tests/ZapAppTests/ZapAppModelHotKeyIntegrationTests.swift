import XCTest
@testable import ZapApp
@testable import ZapCore

@MainActor
final class ZapAppModelHotKeyIntegrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearZapAppModelDefaults()
    }

    override func tearDown() {
        clearZapAppModelDefaults()
        super.tearDown()
    }

    func testInitialRegistrationPassesDockFinderManualAndWindowShortcuts() {
        let manualID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
        let manualShortcuts = [manualShortcut(id: manualID, keyCode: 17, modifiers: [.control, .option])]
        storeManualShortcuts(manualShortcuts)
        UserDefaults.standard.set([ShortcutModifier.control.rawValue, ShortcutModifier.shift.rawValue], forKey: "shortcut_modifiers")
        UserDefaults.standard.set(true, forKey: "finder_shortcut_enabled")
        let windowShortcuts = [windowShortcut(.leftHalf, keyCode: 123, modifiers: [.option, .command])]
        let windowModel = WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: windowShortcuts)
        )
        let hotKeyService = CapturingHotKeyService()

        _ = makeModel(windowManagementModel: windowModel, hotKeyService: hotKeyService)

        XCTAssertEqual(hotKeyService.registrations.count, 1)
        XCTAssertEqual(hotKeyService.registrations[0].modifiers, [.control, .shift])
        XCTAssertTrue(hotKeyService.registrations[0].finderShortcutEnabled)
        XCTAssertEqual(hotKeyService.registrations[0].manualShortcuts, manualShortcuts)
        XCTAssertEqual(hotKeyService.registrations[0].windowShortcuts, windowShortcuts)
    }

    func testDockFinderManualAndWindowCallbacksRouteToExistingBehaviors() async {
        let dockItem = DockItem(
            name: "Terminal",
            url: URL(fileURLWithPath: "/Applications/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal"
        )
        let manualID = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
        let manual = manualShortcut(
            id: manualID,
            name: "Notes",
            url: URL(fileURLWithPath: "/Applications/Notes.app"),
            bundleIdentifier: "com.apple.Notes",
            keyCode: 45,
            modifiers: [.control, .option]
        )
        storeManualShortcuts([manual])
        let launcher = CapturingAppLauncher()
        let windowPerformer = CapturingWindowManagementPerformer()
        let windowModel = WindowManagementModel(
            service: windowPerformer,
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [windowShortcut(.leftHalf, keyCode: 123, modifiers: [.option, .command])])
        )
        let hotKeyService = CapturingHotKeyService()

        let model = makeModel(
            dockItems: [dockItem],
            appLauncher: launcher,
            windowManagementModel: windowModel,
            hotKeyService: hotKeyService
        )

        hotKeyService.onDockHotKey?(.one)
        await Task.yield()
        XCTAssertEqual(launcher.activatedItems, [dockItem])

        hotKeyService.onFinderHotKey?()
        await Task.yield()
        XCTAssertEqual(launcher.activateFinderCallCount, 1)

        hotKeyService.onManualHotKey?(manualID)
        await Task.yield()
        XCTAssertEqual(launcher.activatedItems, [dockItem, manual.dockItem])

        hotKeyService.onWindowHotKey?(.leftHalf)
        await Task.yield()
        XCTAssertEqual(windowPerformer.performedActions, [.leftHalf])
        XCTAssertEqual(launcher.activatedItems, [dockItem, manual.dockItem])
        XCTAssertEqual(launcher.activateFinderCallCount, 1)
        _ = model
    }

    func testHotKeyCallbacksHopToMainActorWhenInvokedOffMainActor() async {
        let dockItem = DockItem(
            name: "Terminal",
            url: URL(fileURLWithPath: "/Applications/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal"
        )
        let manualID = UUID(uuidString: "00000000-0000-0000-0000-000000000303")!
        let manual = manualShortcut(
            id: manualID,
            name: "Notes",
            url: URL(fileURLWithPath: "/Applications/Notes.app"),
            bundleIdentifier: "com.apple.Notes",
            keyCode: 45,
            modifiers: [.control, .option]
        )
        storeManualShortcuts([manual])
        let callbacksComplete = expectation(description: "Hotkey callbacks complete")
        callbacksComplete.expectedFulfillmentCount = 4
        let launcher = CapturingAppLauncher()
        launcher.onActivateOrLaunch = { callbacksComplete.fulfill() }
        launcher.onActivateFinder = { callbacksComplete.fulfill() }
        let windowPerformer = CapturingWindowManagementPerformer()
        windowPerformer.onPerform = { callbacksComplete.fulfill() }
        let windowModel = WindowManagementModel(
            service: windowPerformer,
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [windowShortcut(.leftHalf, keyCode: 123, modifiers: [.option, .command])])
        )
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            dockItems: [dockItem],
            appLauncher: launcher,
            windowManagementModel: windowModel,
            hotKeyService: hotKeyService
        )
        let callbacks = hotKeyService.callbacks

        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                callbacks.onDockHotKey?(.one)
                callbacks.onFinderHotKey?()
                callbacks.onManualHotKey?(manualID)
                callbacks.onWindowHotKey?(.leftHalf)
                continuation.resume()
            }
        }
        await fulfillment(of: [callbacksComplete], timeout: 1.0)

        XCTAssertEqual(launcher.activatedItems, [dockItem, manual.dockItem])
        XCTAssertEqual(launcher.activateFinderCallCount, 1)
        XCTAssertEqual(windowPerformer.performedActions, [.leftHalf])
        _ = model
    }

    func testUpdatingWindowShortcutSavesAndReregistersWithNewWindowShortcuts() {
        let initialShortcuts = [windowShortcut(.leftHalf, keyCode: 123, modifiers: [.option, .command])]
        let shortcutStore = InMemoryWindowShortcutStore(shortcuts: initialShortcuts)
        let windowModel = WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: shortcutStore
        )
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(windowManagementModel: windowModel, hotKeyService: hotKeyService)
        hotKeyService.registrations.removeAll()

        windowModel.setShortcut(action: .leftHalf, keyCode: 124, keyDisplayName: "→", modifiers: [.control, .option])

        XCTAssertEqual(shortcutStore.savedShortcuts.count, 1)
        XCTAssertEqual(shortcutStore.savedShortcuts[0].first { $0.action == .leftHalf }?.keyCode, 124)
        XCTAssertEqual(hotKeyService.registrations.count, 1)
        _ = model
        XCTAssertEqual(hotKeyService.registrations[0].windowShortcuts.first { $0.action == .leftHalf }?.keyCode, 124)
    }

    func testStartingWindowShortcutRecordingReregistersWithoutWindowShortcuts() {
        let initialShortcuts = [windowShortcut(.center, keyCode: 0, modifiers: [.control])]
        let windowModel = WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: initialShortcuts)
        )
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(windowManagementModel: windowModel, hotKeyService: hotKeyService)
        hotKeyService.registrations.removeAll()

        windowModel.setShortcutRecordingActive(true)

        _ = model
        XCTAssertEqual(hotKeyService.registrations.count, 1)
        XCTAssertEqual(hotKeyService.registrations[0].windowShortcuts, [])
    }

    func testHotKeyRegistrationErrorAndWindowShortcutValidationErrorRemainSeparate() {
        let windowModel = WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [windowShortcut(.fullscreen, keyCode: 3, modifiers: [.option, .command])])
        )
        let hotKeyService = CapturingHotKeyService()
        hotKeyService.nextRegistrationError = "Some window shortcuts could not be registered: Fullscreen (conflict)"
        let model = makeModel(windowManagementModel: windowModel, hotKeyService: hotKeyService)

        windowModel.setShortcut(action: .fullscreen, keyCode: 3, keyDisplayName: "F", modifiers: [])

        XCTAssertEqual(model.registrationError, "Some window shortcuts could not be registered: Fullscreen (conflict)")
        XCTAssertEqual(windowModel.shortcutRegistrationError, "Select at least one modifier key.")
    }

    private func makeModel(
        dockItems: [DockItem] = [],
        appLauncher: CapturingAppLauncher = CapturingAppLauncher(),
        windowManagementModel: WindowManagementModel,
        hotKeyService: CapturingHotKeyService
    ) -> ZapAppModel {
        ZapAppModel(
            dockItemProvider: StubDockItemProvider(items: dockItems),
            appLauncher: appLauncher,
            loginItemService: StubLoginItemService(),
            updateService: UpdateService(driverFactory: { StubUpdateDriver() }, buildTagProvider: { nil }),
            windowManagementModel: windowManagementModel,
            hotKeyServiceFactory: { onDockHotKey, onFinderHotKey, onManualHotKey, onWindowHotKey in
                hotKeyService.onDockHotKey = onDockHotKey
                hotKeyService.onFinderHotKey = onFinderHotKey
                hotKeyService.onManualHotKey = onManualHotKey
                hotKeyService.onWindowHotKey = onWindowHotKey
                return hotKeyService
            }
        )
    }

    private func manualShortcut(
        id: UUID,
        name: String = "Manual App",
        url: URL = URL(fileURLWithPath: "/Applications/Manual.app"),
        bundleIdentifier: String? = "com.example.Manual",
        keyCode: UInt32,
        modifiers: Set<ShortcutModifier>
    ) -> ManualShortcut {
        ManualShortcut(
            id: id,
            name: name,
            url: url,
            bundleIdentifier: bundleIdentifier,
            keyCode: keyCode,
            keyDisplayName: "Key\(keyCode)",
            modifiers: modifiers,
            isEnabled: true
        )
    }

    private func windowShortcut(
        _ action: WindowAction,
        keyCode: UInt32,
        modifiers: Set<ShortcutModifier>
    ) -> WindowShortcut {
        WindowShortcut(
            action: action,
            keyCode: keyCode,
            keyDisplayName: action.displayName,
            modifiers: modifiers,
            isEnabled: true
        )
    }

    private func storeManualShortcuts(_ shortcuts: [ManualShortcut]) {
        let data = try! JSONEncoder().encode(shortcuts)
        UserDefaults.standard.set(data, forKey: "manual_shortcuts")
    }

    private func clearZapAppModelDefaults() {
        for key in ["shortcut_modifiers", "finder_shortcut_enabled", "manual_shortcuts", "start_at_login", "window_shortcuts", "window_management_enabled"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

private final class CapturingHotKeyService: GlobalHotKeyServicing {
    struct Registration: Equatable {
        let modifiers: Set<ShortcutModifier>
        let finderShortcutEnabled: Bool
        let manualShortcuts: [ManualShortcut]
        let windowShortcuts: [WindowShortcut]
    }

    struct Callbacks: @unchecked Sendable {
        let onDockHotKey: ((NumberKey) -> Void)?
        let onFinderHotKey: (() -> Void)?
        let onManualHotKey: ((UUID) -> Void)?
        let onWindowHotKey: ((WindowAction) -> Void)?
    }

    var registrations: [Registration] = []
    var unregisterCallCount = 0
    var nextRegistrationError: String?
    var onDockHotKey: ((NumberKey) -> Void)?
    var onFinderHotKey: (() -> Void)?
    var onManualHotKey: ((UUID) -> Void)?
    var onWindowHotKey: ((WindowAction) -> Void)?

    var callbacks: Callbacks {
        Callbacks(
            onDockHotKey: onDockHotKey,
            onFinderHotKey: onFinderHotKey,
            onManualHotKey: onManualHotKey,
            onWindowHotKey: onWindowHotKey
        )
    }

    func register(
        modifiers: Set<ShortcutModifier>,
        finderShortcutEnabled: Bool,
        manualShortcuts: [ManualShortcut],
        windowShortcuts: [WindowShortcut]
    ) -> String? {
        registrations.append(Registration(
            modifiers: modifiers,
            finderShortcutEnabled: finderShortcutEnabled,
            manualShortcuts: manualShortcuts,
            windowShortcuts: windowShortcuts
        ))
        return nextRegistrationError
    }

    func unregister() {
        unregisterCallCount += 1
    }
}

private final class CapturingWindowManagementPerformer: WindowActionPerforming {
    var performedActions: [WindowAction] = []
    var onPerform: (() -> Void)?

    func perform(action: WindowAction) -> WindowManagementResult {
        performedActions.append(action)
        onPerform?()
        return .success(action: action, frame: .zero)
    }
}

private final class InMemoryWindowShortcutStore: WindowShortcutStoring {
    private let initialShortcuts: [WindowShortcut]
    var savedShortcuts: [[WindowShortcut]] = []

    init(shortcuts: [WindowShortcut]) {
        self.initialShortcuts = shortcuts
    }

    func loadWindowShortcuts() -> [WindowShortcut] {
        initialShortcuts
    }

    func saveWindowShortcuts(_ shortcuts: [WindowShortcut]) {
        savedShortcuts.append(shortcuts)
    }
}

private struct StubDockItemProvider: DockItemProviding {
    let items: [DockItem]

    func currentDockItems() -> [DockItem] {
        items
    }
}

private final class CapturingAppLauncher: AppLaunching {
    var activatedItems: [DockItem] = []
    var activateFinderCallCount = 0
    var onActivateOrLaunch: (() -> Void)?
    var onActivateFinder: (() -> Void)?

    func activateOrLaunch(_ item: DockItem) {
        activatedItems.append(item)
        onActivateOrLaunch?()
    }

    func activateFinder() {
        activateFinderCallCount += 1
        onActivateFinder?()
    }
}

private struct StubLoginItemService: LoginItemControlling {
    func setStartAtLoginEnabled(_ isEnabled: Bool) throws {}
}

@MainActor
private final class StubUpdateDriver: UpdateDriving {
    var automaticallyChecksForUpdates = false
    var canCheckForUpdates = false

    func start() {}
    func checkForUpdates() {}
}
