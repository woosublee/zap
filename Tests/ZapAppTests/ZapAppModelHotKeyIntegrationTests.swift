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

    func testActiveApplicationToggleShortcutStartsUnset() {
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService
        )

        XCTAssertEqual(model.activeApplicationToggleShortcut, .unset)
        XCTAssertEqual(
            hotKeyService.registrations.last?.activeApplicationToggleShortcut,
            .unset
        )
        XCTAssertEqual(hotKeyService.registrations.last?.scope, .all)
    }

    func testSettingActiveApplicationToggleShortcutPersistsAndReregisters() throws {
        let suiteName = "ActiveApplicationTogglePersistence.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            userDefaults: defaults
        )
        hotKeyService.registrations.removeAll()

        model.setActiveApplicationToggleShortcut(
            keyCode: 17,
            keyDisplayName: "T",
            modifiers: [.control, .option]
        )

        let data = try XCTUnwrap(defaults.data(
            forKey: "active_application_toggle_shortcut"
        ))
        let stored = try JSONDecoder().decode(
            ActiveApplicationToggleShortcut.self,
            from: data
        )

        XCTAssertEqual(stored, model.activeApplicationToggleShortcut)
        XCTAssertEqual(hotKeyService.registrations.count, 1)
        XCTAssertEqual(
            hotKeyService.registrations[0].activeApplicationToggleShortcut,
            stored
        )

        let restoredService = CapturingHotKeyService()
        let restoredModel = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: restoredService,
            userDefaults: defaults
        )

        XCTAssertEqual(restoredModel.activeApplicationToggleShortcut, stored)
    }

    func testClearingActiveApplicationToggleShortcutRemovesStoredValue() {
        let suiteName = "ActiveApplicationToggleClear.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            userDefaults: defaults
        )

        model.setActiveApplicationToggleShortcut(
            keyCode: 17,
            keyDisplayName: "T",
            modifiers: [.control]
        )
        hotKeyService.registrations.removeAll()

        model.clearActiveApplicationToggleShortcut()

        XCTAssertEqual(model.activeApplicationToggleShortcut, .unset)
        XCTAssertNil(defaults.data(forKey: "active_application_toggle_shortcut"))
        XCTAssertEqual(
            hotKeyService.registrations.last?.activeApplicationToggleShortcut,
            .unset
        )
    }

    func testNonDataActiveApplicationToggleShortcutRestoresUnsetStateAndRemovesStoredValue() {
        let suiteName = "ActiveApplicationToggleNonData.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("not shortcut data", forKey: "active_application_toggle_shortcut")

        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: CapturingHotKeyService(),
            userDefaults: defaults
        )

        XCTAssertEqual(model.activeApplicationToggleShortcut, .unset)
        XCTAssertNil(defaults.object(forKey: "active_application_toggle_shortcut"))
    }

    func testNonRegisterableActiveApplicationToggleShortcutRestoresUnsetStateAndRemovesStoredValue() throws {
        let suiteName = "ActiveApplicationToggleNonRegisterable.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let invalidShortcut = ActiveApplicationToggleShortcut(
            keyCode: 17,
            keyDisplayName: "T",
            modifiers: []
        )
        defaults.set(
            try JSONEncoder().encode(invalidShortcut),
            forKey: "active_application_toggle_shortcut"
        )

        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: CapturingHotKeyService(),
            userDefaults: defaults
        )

        XCTAssertEqual(model.activeApplicationToggleShortcut, .unset)
        XCTAssertNil(defaults.object(forKey: "active_application_toggle_shortcut"))
    }

    func testCorruptActiveApplicationToggleShortcutRestoresUnsetState() {
        let suiteName = "ActiveApplicationToggleCorrupt.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(
            Data([0xFF, 0x00]),
            forKey: "active_application_toggle_shortcut"
        )

        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: CapturingHotKeyService(),
            userDefaults: defaults
        )

        XCTAssertEqual(model.activeApplicationToggleShortcut, .unset)
        XCTAssertNil(defaults.data(forKey: "active_application_toggle_shortcut"))
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

    func testActiveApplicationToggleCallbackUsesExistingToggleMethod() async {
        let suiteName = "ActiveApplicationToggleCallback.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            userDefaults: defaults,
            activeApplicationProvider: {
                ActiveApplication(
                    name: "Safari",
                    bundleIdentifier: "com.apple.Safari"
                )
            }
        )

        hotKeyService.onActiveApplicationToggleHotKey?()
        await Task.yield()

        XCTAssertTrue(model.isActiveApplicationDisabled)
        XCTAssertEqual(
            defaults.dictionary(forKey: "disabled_hot_key_applications")
                as? [String: String],
            ["com.apple.Safari": "Safari"]
        )
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

    func testPausingAndResumingHotKeysUnregistersAndRestoresRegistration() async {
        let hotKeyService = CapturingHotKeyService()
        let scheduler = CapturingPauseScheduler()
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            now: { now },
            pauseScheduler: scheduler
        )
        hotKeyService.registrations.removeAll()
        hotKeyService.unregisterCallCount = 0

        model.pauseHotKeys(for: 10 * 60)

        XCTAssertEqual(hotKeyService.unregisterCallCount, 1)
        XCTAssertEqual(model.pausedUntil, now.addingTimeInterval(10 * 60))
        XCTAssertEqual(scheduler.scheduledIntervals, [10 * 60])

        scheduler.fire()
        await Task.yield()
        XCTAssertEqual(hotKeyService.registrations.count, 1)
        XCTAssertFalse(model.areHotKeysPaused)

        model.pauseHotKeysIndefinitely()
        XCTAssertEqual(hotKeyService.unregisterCallCount, 2)
        XCTAssertTrue(model.isPausedIndefinitely)

        model.resumeHotKeys()
        XCTAssertEqual(hotKeyService.registrations.count, 2)
        XCTAssertFalse(model.areHotKeysPaused)
    }

    func testDisabledActiveApplicationKeepsOnlyControlRegistrationAndSecondToggleRestoresAll() {
        let suiteName = "ActiveApplicationToggleScope.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        storeActiveApplicationToggleShortcut(
            ActiveApplicationToggleShortcut(
                keyCode: 17,
                keyDisplayName: "T",
                modifiers: [.control, .option]
            ),
            in: defaults
        )

        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            userDefaults: defaults,
            activeApplicationProvider: {
                ActiveApplication(
                    name: "Safari",
                    bundleIdentifier: "com.apple.Safari"
                )
            }
        )
        hotKeyService.registrations.removeAll()
        hotKeyService.unregisterCallCount = 0

        model.toggleHotKeysForActiveApplication()

        XCTAssertTrue(model.isActiveApplicationDisabled)
        XCTAssertEqual(hotKeyService.unregisterCallCount, 0)
        XCTAssertEqual(
            hotKeyService.registrations.last?.scope,
            .activeApplicationToggleOnly
        )

        model.toggleHotKeysForActiveApplication()

        XCTAssertFalse(model.isActiveApplicationDisabled)
        XCTAssertEqual(hotKeyService.registrations.last?.scope, .all)
    }

    func testGlobalPauseUnregistersControlAndRegularHotKeys() {
        let suiteName = "ActiveApplicationTogglePause.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        storeActiveApplicationToggleShortcut(
            ActiveApplicationToggleShortcut(
                keyCode: 17,
                keyDisplayName: "T",
                modifiers: [.control]
            ),
            in: defaults
        )

        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            userDefaults: defaults
        )
        hotKeyService.registrations.removeAll()
        hotKeyService.unregisterCallCount = 0

        model.pauseHotKeysIndefinitely()

        XCTAssertEqual(hotKeyService.unregisterCallCount, 1)
        XCTAssertEqual(hotKeyService.registrations, [])
    }

    func testMissingActiveApplicationDoesNotChangeDisabledStateOrPersistence() async {
        let suiteName = "ActiveApplicationToggleMissingApp.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            userDefaults: defaults,
            activeApplicationProvider: { nil }
        )
        hotKeyService.registrations.removeAll()

        hotKeyService.onActiveApplicationToggleHotKey?()
        await Task.yield()

        XCTAssertEqual(model.disabledApplications, [:])
        XCTAssertNil(defaults.dictionary(forKey: "disabled_hot_key_applications"))
        XCTAssertEqual(hotKeyService.registrations, [])
    }

    func testDisabledActiveApplicationUsesControlOnlyRegistrationAndOtherApplicationRestoresAll() async {
        let workspaceNotifications = NotificationCenter()
        var currentApplication = ActiveApplication(name: "Safari", bundleIdentifier: "com.apple.Safari")
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            activeApplicationProvider: { currentApplication },
            workspaceNotificationCenter: workspaceNotifications
        )
        hotKeyService.registrations.removeAll()
        hotKeyService.unregisterCallCount = 0

        model.toggleHotKeysForActiveApplication()
        XCTAssertEqual(hotKeyService.unregisterCallCount, 0)
        XCTAssertEqual(hotKeyService.registrations.last?.scope, .activeApplicationToggleOnly)
        XCTAssertTrue(model.isActiveApplicationDisabled)

        currentApplication = ActiveApplication(name: "Notes", bundleIdentifier: "com.apple.Notes")
        workspaceNotifications.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
        await Task.yield()

        XCTAssertEqual(model.activeApplication, currentApplication)
        XCTAssertEqual(hotKeyService.registrations.last?.scope, .all)

        currentApplication = ActiveApplication(name: "Safari", bundleIdentifier: "com.apple.Safari")
        workspaceNotifications.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
        await Task.yield()

        XCTAssertEqual(hotKeyService.registrations.last?.scope, .activeApplicationToggleOnly)
        XCTAssertTrue(model.isActiveApplicationDisabled)
    }

    func testPausedStateAndDisabledApplicationsRestoreFromUserDefaults() {
        let suiteName = "ZapAppModelHotKeyIntegrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSinceReferenceDate: 2_000)
        let pausedUntil = now.addingTimeInterval(30 * 60)
        defaults.set(pausedUntil, forKey: "hot_keys_paused_until")
        defaults.set(["com.apple.Safari": "Safari"], forKey: "disabled_hot_key_applications")
        let hotKeyService = CapturingHotKeyService()

        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            userDefaults: defaults,
            now: { now },
            activeApplicationProvider: { ActiveApplication(name: "Notes", bundleIdentifier: "com.apple.Notes") }
        )

        XCTAssertEqual(model.pausedUntil, pausedUntil)
        XCTAssertEqual(model.disabledApplications, ["com.apple.Safari": "Safari"])
        XCTAssertEqual(hotKeyService.unregisterCallCount, 1)
    }

    func testExpiredPausedStateIsClearedOnLaunch() {
        let suiteName = "ZapAppModelHotKeyIntegrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSinceReferenceDate: 3_000)
        defaults.set(now.addingTimeInterval(-1), forKey: "hot_keys_paused_until")
        let hotKeyService = CapturingHotKeyService()

        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            userDefaults: defaults,
            now: { now }
        )

        XCTAssertNil(model.pausedUntil)
        XCTAssertNil(defaults.object(forKey: "hot_keys_paused_until"))
        XCTAssertEqual(hotKeyService.registrations.count, 1)
    }

    func testDirectMenuActionsRemainAvailableWhileHotKeysArePaused() {
        let dockItem = DockItem(
            name: "Terminal",
            url: URL(fileURLWithPath: "/Applications/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal"
        )
        let launcher = CapturingAppLauncher()
        let windowPerformer = CapturingWindowManagementPerformer()
        let windowModel = WindowManagementModel(
            service: windowPerformer,
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
        )
        let model = makeModel(
            dockItems: [dockItem],
            appLauncher: launcher,
            windowManagementModel: windowModel,
            hotKeyService: CapturingHotKeyService()
        )

        model.pauseHotKeysIndefinitely()
        model.activateDockItem(for: .one)
        model.activateFinder()
        _ = model.windowManagementModel.perform(action: .leftHalf)

        XCTAssertEqual(launcher.activatedItems, [dockItem])
        XCTAssertEqual(launcher.activateFinderCallCount, 1)
        XCTAssertEqual(windowPerformer.performedActions, [.leftHalf])
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
        hotKeyService: CapturingHotKeyService,
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        activeApplicationProvider: @escaping () -> ActiveApplication? = { nil },
        workspaceNotificationCenter: NotificationCenter = NotificationCenter(),
        pauseScheduler: any HotKeyPauseScheduling = CapturingPauseScheduler()
    ) -> ZapAppModel {
        ZapAppModel(
            dockItemProvider: StubDockItemProvider(items: dockItems),
            appLauncher: appLauncher,
            loginItemService: StubLoginItemService(),
            updateService: UpdateService(driverFactory: { StubUpdateDriver() }, buildTagProvider: { nil }),
            windowManagementModel: windowManagementModel,
            userDefaults: userDefaults,
            now: now,
            activeApplicationProvider: activeApplicationProvider,
            workspaceNotificationCenter: workspaceNotificationCenter,
            pauseScheduler: pauseScheduler,
            hotKeyServiceFactory: {
                onDockHotKey,
                onFinderHotKey,
                onManualHotKey,
                onWindowHotKey,
                onActiveApplicationToggleHotKey in

                hotKeyService.onDockHotKey = onDockHotKey
                hotKeyService.onFinderHotKey = onFinderHotKey
                hotKeyService.onManualHotKey = onManualHotKey
                hotKeyService.onWindowHotKey = onWindowHotKey
                hotKeyService.onActiveApplicationToggleHotKey =
                    onActiveApplicationToggleHotKey
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

    private func storeActiveApplicationToggleShortcut(
        _ shortcut: ActiveApplicationToggleShortcut,
        in defaults: UserDefaults
    ) {
        let data = try! JSONEncoder().encode(shortcut)
        defaults.set(data, forKey: "active_application_toggle_shortcut")
    }

    private func clearZapAppModelDefaults() {
        for key in ["shortcut_modifiers", "finder_shortcut_enabled", "manual_shortcuts", "start_at_login", "window_shortcuts", "window_management_enabled", "hot_keys_paused_until", "hot_keys_paused_indefinitely", "disabled_hot_key_applications", "active_application_toggle_shortcut"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

private final class CapturingPauseScheduler: HotKeyPauseScheduling {
    var scheduledIntervals: [TimeInterval] = []
    private var action: (() -> Void)?

    func schedule(after interval: TimeInterval, action: @escaping () -> Void) {
        scheduledIntervals.append(interval)
        self.action = action
    }

    func cancel() {
        action = nil
    }

    func fire() {
        let action = action
        self.action = nil
        action?()
    }
}

private final class CapturingHotKeyService: GlobalHotKeyServicing {
    struct Registration: Equatable {
        let modifiers: Set<ShortcutModifier>
        let finderShortcutEnabled: Bool
        let manualShortcuts: [ManualShortcut]
        let windowShortcuts: [WindowShortcut]
        let activeApplicationToggleShortcut: ActiveApplicationToggleShortcut
        let scope: GlobalHotKeyRegistrationScope
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
    var onActiveApplicationToggleHotKey: (() -> Void)?

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
        windowShortcuts: [WindowShortcut],
        activeApplicationToggleShortcut: ActiveApplicationToggleShortcut,
        scope: GlobalHotKeyRegistrationScope
    ) -> String? {
        registrations.append(Registration(
            modifiers: modifiers,
            finderShortcutEnabled: finderShortcutEnabled,
            manualShortcuts: manualShortcuts,
            windowShortcuts: windowShortcuts,
            activeApplicationToggleShortcut: activeApplicationToggleShortcut,
            scope: scope
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
