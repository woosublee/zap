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
        let presenter = CapturingShortcutHUDPresenter()

        let model = makeModel(
            dockItems: [dockItem],
            appLauncher: launcher,
            windowManagementModel: windowModel,
            hotKeyService: hotKeyService,
            shortcutHUDPresenter: presenter
        )

        hotKeyService.onDockHotKey?(.one)
        await Task.yield()
        XCTAssertEqual(launcher.activatedItems, [dockItem])
        let presentationCountAfterDock = presenter.presentations.count

        hotKeyService.onFinderHotKey?()
        await Task.yield()
        XCTAssertEqual(launcher.activateFinderCallCount, 1)
        XCTAssertEqual(
            presenter.presentations.map(\.payload.appName),
            ["Terminal", "Finder"]
        )

        hotKeyService.onManualHotKey?(manualID)
        await Task.yield()
        XCTAssertEqual(launcher.activatedItems, [dockItem, manual.dockItem])

        hotKeyService.onWindowHotKey?(.leftHalf)
        await Task.yield()
        XCTAssertEqual(windowPerformer.performedActions, [.leftHalf])
        XCTAssertEqual(launcher.activatedItems, [dockItem, manual.dockItem])
        XCTAssertEqual(launcher.activateFinderCallCount, 1)
        XCTAssertEqual(
            presenter.presentations.count,
            presentationCountAfterDock + 1
        )
        _ = model
    }

    func testAutomaticDockHotKeyPresentsActivatedPayloadOnCapturedDisplay() async {
        let item = DockItem(
            name: "Terminal",
            url: URL(fileURLWithPath: "/Applications/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal"
        )
        let display = DisplayFrame(
            frame: CGRect(x: 1000, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 1000, y: 25, width: 1000, height: 775),
            isMain: false
        )
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            dockItems: [item],
            appLauncher: CapturingAppLauncher(),
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            shortcutHUDPresenter: presenter,
            shortcutHUDScreenResolver: StubShortcutHUDScreenResolver(display: display),
            shortcutHUDLocalizedDisplayName: { _ in "Localized Terminal" }
        )

        hotKeyService.onDockHotKey?(.one)
        await Task.yield()

        XCTAssertEqual(
            presenter.presentations,
            [.init(
                payload: ShortcutHUDPayload(
                    action: .appActivated,
                    appName: "Localized Terminal",
                    bundleIdentifier: item.bundleIdentifier,
                    applicationURL: item.url
                ),
                display: display
            )]
        )
        _ = model
    }

    func testFinderHotKeyPresentsCanonicalPayloadOnCapturedDisplay() async {
        let display = DisplayFrame(
            frame: CGRect(x: 1000, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 1000, y: 25, width: 1000, height: 775),
            isMain: false
        )
        let launcher = CapturingAppLauncher()
        launcher.nextFinderOutcome = .launched
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            appLauncher: launcher,
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            shortcutHUDPresenter: presenter,
            shortcutHUDScreenResolver: StubShortcutHUDScreenResolver(
                display: display
            )
        )

        hotKeyService.onFinderHotKey?()
        await Task.yield()

        XCTAssertEqual(
            presenter.presentations,
            [.init(
                payload: ShortcutHUDPayload(
                    action: .appActivated,
                    appName: "Finder",
                    bundleIdentifier: "com.apple.finder",
                    applicationURL: nil
                ),
                display: display
            )]
        )
        _ = model
    }

    func testFailedFinderHotKeyDoesNotBeepOrPresentHUD() async {
        var modelBeepCount = 0
        let launcher = CapturingAppLauncher()
        launcher.nextFinderOutcome = .failed
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            appLauncher: launcher,
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            shortcutHUDPresenter: presenter,
            beep: { modelBeepCount += 1 }
        )

        hotKeyService.onFinderHotKey?()
        await Task.yield()

        XCTAssertEqual(launcher.activateFinderCallCount, 1)
        XCTAssertEqual(modelBeepCount, 0)
        XCTAssertTrue(presenter.presentations.isEmpty)
        _ = model
    }

    func testAutomaticDockHotKeyResolvesDockItemsOnceForLaunchAndPayload() async {
        let item = DockItem(
            name: "Terminal",
            url: URL(fileURLWithPath: "/Applications/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal"
        )
        let provider = CountingDockItemProvider(items: [item])
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            dockItemProvider: provider,
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            shortcutHUDPresenter: presenter
        )
        let callsAfterInitialization = provider.currentDockItemsCallCount

        hotKeyService.onDockHotKey?(.one)
        await Task.yield()

        XCTAssertEqual(provider.currentDockItemsCallCount, callsAfterInitialization + 1)
        XCTAssertEqual(presenter.presentations.first?.payload.applicationURL, item.url)
        XCTAssertEqual(presenter.presentations.first?.payload.bundleIdentifier, item.bundleIdentifier)
        _ = model
    }

    func testDockMenuLaunchNeverPresentsHUD() {
        let item = DockItem(
            name: "Terminal",
            url: URL(fileURLWithPath: "/Applications/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal"
        )
        let presenter = CapturingShortcutHUDPresenter()
        let model = makeModel(
            dockItems: [item],
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: CapturingHotKeyService(),
            shortcutHUDPresenter: presenter
        )

        model.activateDockItemFromMenu(for: .one)

        XCTAssertTrue(presenter.presentations.isEmpty)
    }

    func testMissingDockSlotBeepsOnceWithoutPresentingHUD() async {
        var beepCount = 0
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            dockItems: [],
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            shortcutHUDPresenter: presenter,
            beep: { beepCount += 1 }
        )

        hotKeyService.onDockHotKey?(.one)
        await Task.yield()

        XCTAssertEqual(beepCount, 1)
        XCTAssertTrue(presenter.presentations.isEmpty)
        _ = model
    }

    func testFailedDockOutcomeDoesNotPresentOrAddCallerBeep() async {
        let item = DockItem(
            name: "Terminal",
            url: URL(fileURLWithPath: "/Applications/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal"
        )
        let launcher = CapturingAppLauncher()
        launcher.nextOutcome = .failed
        var callerBeepCount = 0
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            dockItems: [item],
            appLauncher: launcher,
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            shortcutHUDPresenter: presenter,
            beep: { callerBeepCount += 1 }
        )

        hotKeyService.onDockHotKey?(.one)
        await Task.yield()

        XCTAssertEqual(callerBeepCount, 0)
        XCTAssertTrue(presenter.presentations.isEmpty)
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

    func testActiveApplicationToggleHotKeyPresentsDisableThenEnable() async {
        let safari = ActiveApplication(name: "Safari", bundleIdentifier: "com.apple.Safari")
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            activeApplicationProvider: { safari },
            shortcutHUDPresenter: presenter
        )

        hotKeyService.onActiveApplicationToggleHotKey?()
        await Task.yield()
        hotKeyService.onActiveApplicationToggleHotKey?()
        await Task.yield()

        XCTAssertEqual(
            presenter.presentations.map(\.payload.action),
            [.appHotKeysDisabled, .appHotKeysEnabled]
        )
        XCTAssertTrue(presenter.presentations.allSatisfy {
            $0.payload.appName == "Safari" &&
            $0.payload.bundleIdentifier == "com.apple.Safari"
        })
        _ = model
    }

    func testMenuActiveApplicationToggleNeverPresentsHUD() {
        let safari = ActiveApplication(name: "Safari", bundleIdentifier: "com.apple.Safari")
        let presenter = CapturingShortcutHUDPresenter()
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: CapturingHotKeyService(),
            activeApplicationProvider: { safari },
            shortcutHUDPresenter: presenter
        )

        XCTAssertEqual(model.toggleHotKeysForActiveApplication(), .disabled(safari))
        XCTAssertTrue(presenter.presentations.isEmpty)
    }

    func testMissingActiveApplicationHotKeyDoesNotBeepOrPresentHUD() async {
        var beepCount = 0
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            activeApplicationProvider: { nil },
            shortcutHUDPresenter: presenter,
            beep: { beepCount += 1 }
        )

        hotKeyService.onActiveApplicationToggleHotKey?()
        await Task.yield()

        XCTAssertEqual(beepCount, 0)
        XCTAssertTrue(presenter.presentations.isEmpty)
        _ = model
    }

    func testLateOlderDockCompletionCannotReplaceNewerHUDRequest() async {
        let first = DockItem(
            name: "First",
            url: URL(fileURLWithPath: "/Applications/First.app"),
            bundleIdentifier: "com.example.First"
        )
        let second = DockItem(
            name: "Second",
            url: URL(fileURLWithPath: "/Applications/Second.app"),
            bundleIdentifier: "com.example.Second"
        )
        let launcher = CapturingAppLauncher()
        launcher.defersCompletion = true
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            dockItems: [first, second],
            appLauncher: launcher,
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            shortcutHUDPresenter: presenter,
            shortcutHUDLocalizedDisplayName: { $0.deletingPathExtension().lastPathComponent }
        )

        hotKeyService.onDockHotKey?(.one)
        await Task.yield()
        hotKeyService.onDockHotKey?(.two)
        await Task.yield()
        launcher.completeLaunch(at: 1, with: .launched)
        launcher.completeLaunch(at: 0, with: .launched)

        XCTAssertEqual(presenter.presentations.map(\.payload.appName), ["Second"])
        _ = model
    }

    func testNewerFailedDockRequestSuppressesOlderLateSuccess() async {
        let first = DockItem(
            name: "First",
            url: URL(fileURLWithPath: "/Applications/First.app"),
            bundleIdentifier: "com.example.First"
        )
        let second = DockItem(
            name: "Second",
            url: URL(fileURLWithPath: "/Applications/Second.app"),
            bundleIdentifier: "com.example.Second"
        )
        let launcher = CapturingAppLauncher()
        launcher.defersCompletion = true
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            dockItems: [first, second],
            appLauncher: launcher,
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            shortcutHUDPresenter: presenter
        )

        hotKeyService.onDockHotKey?(.one)
        await Task.yield()
        hotKeyService.onDockHotKey?(.two)
        await Task.yield()
        launcher.completeLaunch(at: 1, with: .failed)
        launcher.completeLaunch(at: 0, with: .launched)

        XCTAssertTrue(presenter.presentations.isEmpty)
        _ = model
    }

    func testLateFinderCompletionCannotReplaceNewerDockHUD() async {
        let item = DockItem(
            name: "Terminal",
            url: URL(fileURLWithPath: "/Applications/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal"
        )
        let launcher = CapturingAppLauncher()
        launcher.defersFinderCompletion = true
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            dockItems: [item],
            appLauncher: launcher,
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            shortcutHUDPresenter: presenter
        )

        hotKeyService.onFinderHotKey?()
        await Task.yield()
        hotKeyService.onDockHotKey?(.one)
        await Task.yield()
        launcher.completeFinderActivation(at: 0, with: .activated)

        XCTAssertEqual(presenter.presentations.map(\.payload.appName), ["Terminal"])
        _ = model
    }

    func testNewerFailedFinderRequestSuppressesOlderLateDockSuccess() async {
        let item = DockItem(
            name: "Terminal",
            url: URL(fileURLWithPath: "/Applications/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal"
        )
        let launcher = CapturingAppLauncher()
        launcher.defersCompletion = true
        launcher.nextFinderOutcome = .failed
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            dockItems: [item],
            appLauncher: launcher,
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            shortcutHUDPresenter: presenter
        )

        hotKeyService.onDockHotKey?(.one)
        await Task.yield()
        hotKeyService.onFinderHotKey?()
        await Task.yield()
        launcher.completeLaunch(at: 0, with: .launched)

        XCTAssertTrue(presenter.presentations.isEmpty)
        _ = model
    }

    func testNewerFailedFinderRequestSuppressesOlderFinderSuccess() async {
        let launcher = CapturingAppLauncher()
        launcher.defersFinderCompletion = true
        let presenter = CapturingShortcutHUDPresenter()
        let hotKeyService = CapturingHotKeyService()
        let model = makeModel(
            appLauncher: launcher,
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: hotKeyService,
            shortcutHUDPresenter: presenter
        )

        hotKeyService.onFinderHotKey?()
        await Task.yield()
        hotKeyService.onFinderHotKey?()
        await Task.yield()
        launcher.completeFinderActivation(at: 1, with: .failed)
        launcher.completeFinderActivation(at: 0, with: .activated)

        XCTAssertTrue(presenter.presentations.isEmpty)
        _ = model
    }

    func testToggleHotKeysDisablesAndEnablesExactApplicationSnapshot() {
        let suiteName = "ToggleOutcome.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let safari = ActiveApplication(
            name: "Safari",
            bundleIdentifier: "com.apple.Safari"
        )
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: CapturingHotKeyService(),
            userDefaults: defaults
        )

        XCTAssertEqual(model.toggleHotKeys(for: safari), .disabled(safari))
        XCTAssertEqual(model.disabledApplications, [safari.bundleIdentifier: safari.name])
        XCTAssertEqual(model.toggleHotKeys(for: safari), .enabled(safari))
        XCTAssertEqual(model.disabledApplications, [:])
    }

    func testToggleHotKeysReturnsNoActiveApplicationWithoutMutationOrBeep() {
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: CapturingHotKeyService()
        )

        XCTAssertEqual(model.toggleHotKeys(for: nil), .noActiveApplication)
        XCTAssertEqual(model.disabledApplications, [:])
    }

    func testMenuConvenienceUsesFreshProviderInsteadOfCachedApplication() {
        let safari = ActiveApplication(name: "Safari", bundleIdentifier: "com.apple.Safari")
        let notes = ActiveApplication(name: "Notes", bundleIdentifier: "com.apple.Notes")
        var providerApplication: ActiveApplication? = safari
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: CapturingHotKeyService(),
            activeApplicationProvider: { providerApplication }
        )
        XCTAssertEqual(model.activeApplication, safari)
        providerApplication = notes

        let outcome = model.toggleHotKeysForActiveApplication()

        XCTAssertEqual(outcome, .disabled(notes))
        XCTAssertEqual(model.activeApplication, notes)
        XCTAssertEqual(model.disabledApplications, [notes.bundleIdentifier: notes.name])
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

        XCTAssertEqual(
            model.toggleHotKeysForActiveApplication(),
            .disabled(ActiveApplication(name: "Safari", bundleIdentifier: "com.apple.Safari"))
        )

        XCTAssertTrue(model.isActiveApplicationDisabled)
        XCTAssertEqual(hotKeyService.unregisterCallCount, 0)
        XCTAssertEqual(
            hotKeyService.registrations.last?.scope,
            .activeApplicationToggleOnly
        )

        XCTAssertEqual(
            model.toggleHotKeysForActiveApplication(),
            .enabled(ActiveApplication(name: "Safari", bundleIdentifier: "com.apple.Safari"))
        )

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

    func testMissingActiveApplicationDoesNotChangeDisabledStateOrPersistence() {
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

        XCTAssertEqual(
            model.toggleHotKeysForActiveApplication(),
            .noActiveApplication
        )

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

    func testMissingManualShortcutUsesInjectedBeep() {
        var beepCount = 0
        let model = makeModel(
            windowManagementModel: WindowManagementModel(
                service: CapturingWindowManagementPerformer(),
                shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
            ),
            hotKeyService: CapturingHotKeyService(),
            beep: { beepCount += 1 }
        )

        model.activateManualShortcut(id: UUID())

        XCTAssertEqual(beepCount, 1)
    }

    func testDirectMenuActionsRemainAvailableWhileHotKeysArePaused() {
        let dockItem = DockItem(
            name: "Terminal",
            url: URL(fileURLWithPath: "/Applications/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal"
        )
        let launcher = CapturingAppLauncher()
        let presenter = CapturingShortcutHUDPresenter()
        let windowPerformer = CapturingWindowManagementPerformer()
        let windowModel = WindowManagementModel(
            service: windowPerformer,
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
        )
        let model = makeModel(
            dockItems: [dockItem],
            appLauncher: launcher,
            windowManagementModel: windowModel,
            hotKeyService: CapturingHotKeyService(),
            shortcutHUDPresenter: presenter
        )

        model.pauseHotKeysIndefinitely()
        model.activateDockItemFromMenu(for: .one)
        model.activateFinder()
        _ = model.windowManagementModel.perform(action: .leftHalf)

        XCTAssertEqual(launcher.activatedItems, [dockItem])
        XCTAssertEqual(launcher.activateFinderCallCount, 1)
        XCTAssertEqual(windowPerformer.performedActions, [.leftHalf])
        XCTAssertTrue(presenter.presentations.isEmpty)
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
        dockItemProvider: (any DockItemProviding)? = nil,
        appLauncher: CapturingAppLauncher? = nil,
        windowManagementModel: WindowManagementModel,
        hotKeyService: CapturingHotKeyService,
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        activeApplicationProvider: @escaping () -> ActiveApplication? = { nil },
        workspaceNotificationCenter: NotificationCenter = NotificationCenter(),
        pauseScheduler: any HotKeyPauseScheduling = CapturingPauseScheduler(),
        shortcutHUDPresenter: (any ShortcutHUDPresenting)? = nil,
        shortcutHUDScreenResolver: (any ShortcutHUDScreenResolving)? = nil,
        shortcutHUDLocalizedDisplayName: @escaping (URL) -> String? = { _ in nil },
        beep: @escaping () -> Void = {}
    ) -> ZapAppModel {
        ZapAppModel(
            dockItemProvider: dockItemProvider ?? StubDockItemProvider(items: dockItems),
            appLauncher: appLauncher ?? CapturingAppLauncher(),
            loginItemService: StubLoginItemService(),
            updateService: UpdateService(driverFactory: { StubUpdateDriver() }, buildTagProvider: { nil }),
            windowManagementModel: windowManagementModel,
            userDefaults: userDefaults,
            now: now,
            activeApplicationProvider: activeApplicationProvider,
            workspaceNotificationCenter: workspaceNotificationCenter,
            pauseScheduler: pauseScheduler,
            shortcutHUDPresenter: shortcutHUDPresenter ?? NoOpShortcutHUDPresenter(),
            shortcutHUDScreenResolver: shortcutHUDScreenResolver ??
                StubShortcutHUDScreenResolver(display: nil),
            shortcutHUDLocalizedDisplayName: shortcutHUDLocalizedDisplayName,
            beep: beep,
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

private final class CountingDockItemProvider: DockItemProviding {
    let items: [DockItem]
    private(set) var currentDockItemsCallCount = 0

    init(items: [DockItem]) {
        self.items = items
    }

    func currentDockItems() -> [DockItem] {
        currentDockItemsCallCount += 1
        return items
    }
}

@MainActor
private final class CapturingShortcutHUDPresenter: ShortcutHUDPresenting {
    struct Presentation: Equatable {
        let payload: ShortcutHUDPayload
        let display: DisplayFrame?
    }

    var presentations: [Presentation] = []

    func present(_ payload: ShortcutHUDPayload, on display: DisplayFrame?) {
        presentations.append(Presentation(payload: payload, display: display))
    }
}

@MainActor
private struct StubShortcutHUDScreenResolver: ShortcutHUDScreenResolving {
    let display: DisplayFrame?

    func resolveScreenBeforeAction() -> DisplayFrame? {
        display
    }
}

private final class CapturingAppLauncher: AppLaunching {
    struct PendingLaunch {
        let item: DockItem
        let completion: (AppLaunchOutcome) -> Void
    }

    struct PendingFinderActivation {
        let completion: (AppLaunchOutcome) -> Void
    }

    var activatedItems: [DockItem] = []
    var activateFinderCallCount = 0
    var nextOutcome: AppLaunchOutcome = .activated
    var nextFinderOutcome: AppLaunchOutcome = .activated
    var defersCompletion = false
    var defersFinderCompletion = false
    var pendingLaunches: [PendingLaunch] = []
    var pendingFinderActivations: [PendingFinderActivation] = []
    var onActivateOrLaunch: (() -> Void)?
    var onActivateFinder: (() -> Void)?

    func activateOrLaunch(
        _ item: DockItem,
        completion: @escaping (AppLaunchOutcome) -> Void
    ) {
        activatedItems.append(item)
        onActivateOrLaunch?()
        if defersCompletion {
            pendingLaunches.append(PendingLaunch(item: item, completion: completion))
        } else {
            completion(nextOutcome)
        }
    }

    func completeLaunch(at index: Int, with outcome: AppLaunchOutcome) {
        pendingLaunches[index].completion(outcome)
    }

    func activateFinder(
        completion: @escaping (AppLaunchOutcome) -> Void
    ) {
        activateFinderCallCount += 1
        onActivateFinder?()
        if defersFinderCompletion {
            pendingFinderActivations.append(
                PendingFinderActivation(completion: completion)
            )
        } else {
            completion(nextFinderOutcome)
        }
    }

    func completeFinderActivation(
        at index: Int,
        with outcome: AppLaunchOutcome
    ) {
        pendingFinderActivations[index].completion(outcome)
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
