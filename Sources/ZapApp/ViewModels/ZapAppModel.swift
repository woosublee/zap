import AppKit
import Foundation
import SwiftUI
import ZapCore

struct ActiveApplication: Equatable {
    let name: String
    let bundleIdentifier: String

    static var current: ActiveApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = application.bundleIdentifier else {
            return nil
        }
        return ActiveApplication(
            name: application.localizedName ?? bundleIdentifier,
            bundleIdentifier: bundleIdentifier
        )
    }
}

enum ActiveApplicationToggleOutcome: Equatable {
    case disabled(ActiveApplication)
    case enabled(ActiveApplication)
    case noActiveApplication
}

protocol HotKeyPauseScheduling: AnyObject {
    func schedule(after interval: TimeInterval, action: @escaping () -> Void)
    func cancel()
}

final class TimerHotKeyPauseScheduler: HotKeyPauseScheduling {
    private var timer: Timer?

    func schedule(after interval: TimeInterval, action: @escaping () -> Void) {
        cancel()
        guard interval > 0 else {
            action()
            return
        }
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.timer = nil
            action()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}

@MainActor
final class ZapAppModel: ObservableObject {
    @Published private(set) var dockItems: [DockItem] = []
    @Published private(set) var manualShortcuts: [ManualShortcut] {
        didSet {
            persistManualShortcuts()
            registerHotKeys()
        }
    }
    @Published private(set) var registrationError: String?
    @Published private(set) var loginItemError: String?
    @Published private(set) var inputSourceRevision = 0
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var isPausedIndefinitely: Bool
    @Published private(set) var activeApplication: ActiveApplication?
    @Published private(set) var disabledApplications: [String: String]
    @Published private(set) var activeApplicationToggleShortcut: ActiveApplicationToggleShortcut

    let windowManagementModel: WindowManagementModel

    private var inputSourceObserver: NSObjectProtocol?
    private var appReopenObserver: NSObjectProtocol?
    private var applicationActivationObserver: NSObjectProtocol?

    @Published var isFinderShortcutEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isFinderShortcutEnabled, forKey: Self.finderShortcutEnabledKey)
            registerHotKeys()
        }
    }

    @Published var selectedModifiers: Set<ShortcutModifier> {
        didSet {
            persistModifiers()
            registerHotKeys()
        }
    }

    @Published var startAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(startAtLogin, forKey: Self.startAtLoginKey)
            updateLoginItem()
        }
    }

    private let dockItemProvider: any DockItemProviding
    private let appLauncher: any AppLaunching
    private let loginItemService: any LoginItemControlling
    private let updateService: UpdateService
    private let userDefaults: UserDefaults
    private let now: () -> Date
    private let activeApplicationProvider: () -> ActiveApplication?
    private let workspaceNotificationCenter: NotificationCenter
    private let pauseScheduler: any HotKeyPauseScheduling
    private let shortcutHUDPresenter: any ShortcutHUDPresenting
    private let shortcutHUDScreenResolver: any ShortcutHUDScreenResolving
    private let shortcutHUDLocalizedDisplayName: (URL) -> String?
    private let beep: () -> Void
    private var shortcutHUDRequestGeneration = 0
    private let hotKeyServiceFactory: (
        @escaping (NumberKey) -> Void,
        @escaping () -> Void,
        @escaping (UUID) -> Void,
        @escaping (WindowAction) -> Void,
        @escaping () -> Void
    ) -> any GlobalHotKeyServicing
    private lazy var hotKeyService: any GlobalHotKeyServicing = hotKeyServiceFactory(
        { [weak self] key in
            Task { @MainActor [weak self] in
                self?.handleDockHotKey(key)
            }
        },
        { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleFinderHotKey()
            }
        },
        { [weak self] id in
            Task { @MainActor [weak self] in
                self?.activateManualShortcut(id: id)
            }
        },
        { [weak self] action in
            Task { @MainActor [weak self] in
                _ = self?.windowManagementModel.perform(action: action)
            }
        },
        { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleActiveApplicationToggleHotKey()
            }
        }
    )

    init(
        dockItemProvider: any DockItemProviding = DockItemProvider(),
        appLauncher: (any AppLaunching)? = nil,
        loginItemService: any LoginItemControlling = LoginItemService(),
        updateService: UpdateService,
        windowManagementModel: WindowManagementModel? = nil,
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        activeApplicationProvider: @escaping () -> ActiveApplication? = { ActiveApplication.current },
        workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        pauseScheduler: any HotKeyPauseScheduling = TimerHotKeyPauseScheduler(),
        shortcutHUDPresenter: (any ShortcutHUDPresenting)? = nil,
        shortcutHUDScreenResolver: (any ShortcutHUDScreenResolving)? = nil,
        shortcutHUDLocalizedDisplayName: @escaping (URL) -> String? = {
            let name = FileManager.default.displayName(atPath: $0.path)
            return name.isEmpty ? nil : name
        },
        beep: @escaping () -> Void = { NSSound.beep() },
        hotKeyServiceFactory: @escaping (
            @escaping (NumberKey) -> Void,
            @escaping () -> Void,
            @escaping (UUID) -> Void,
            @escaping (WindowAction) -> Void,
            @escaping () -> Void
        ) -> any GlobalHotKeyServicing = {
            onDockHotKey,
            onFinderHotKey,
            onManualHotKey,
            onWindowHotKey,
            onActiveApplicationToggleHotKey in

            GlobalHotKeyService(
                onDockHotKey: onDockHotKey,
                onFinderHotKey: onFinderHotKey,
                onManualHotKey: onManualHotKey,
                onWindowHotKey: onWindowHotKey,
                onActiveApplicationToggleHotKey: onActiveApplicationToggleHotKey
            )
        }
    ) {
        self.dockItemProvider = dockItemProvider
        self.appLauncher = appLauncher ?? AppLauncher()
        self.loginItemService = loginItemService
        self.updateService = updateService
        self.windowManagementModel = windowManagementModel ?? WindowManagementModel()
        self.userDefaults = userDefaults
        self.now = now
        self.activeApplicationProvider = activeApplicationProvider
        self.workspaceNotificationCenter = workspaceNotificationCenter
        self.pauseScheduler = pauseScheduler
        self.shortcutHUDPresenter = shortcutHUDPresenter ?? ShortcutHUDPresenter()
        self.shortcutHUDScreenResolver = shortcutHUDScreenResolver ?? ShortcutHUDScreenResolver()
        self.shortcutHUDLocalizedDisplayName = shortcutHUDLocalizedDisplayName
        self.beep = beep
        self.hotKeyServiceFactory = hotKeyServiceFactory
        self.manualShortcuts = Self.loadManualShortcuts()
        self.isFinderShortcutEnabled = UserDefaults.standard.bool(forKey: Self.finderShortcutEnabledKey)
        self.selectedModifiers = Self.loadModifiers()
        self.startAtLogin = UserDefaults.standard.bool(forKey: Self.startAtLoginKey)

        let currentDate = now()
        let isPausedIndefinitely = userDefaults.bool(forKey: Self.hotKeysPausedIndefinitelyKey)
        let storedPausedUntil = userDefaults.object(forKey: Self.hotKeysPausedUntilKey) as? Date
        self.isPausedIndefinitely = isPausedIndefinitely
        self.pausedUntil = !isPausedIndefinitely && storedPausedUntil.map { $0 > currentDate } == true
            ? storedPausedUntil
            : nil
        self.activeApplication = activeApplicationProvider()
        self.disabledApplications = userDefaults.dictionary(forKey: Self.disabledApplicationsKey) as? [String: String] ?? [:]
        self.activeApplicationToggleShortcut = Self.loadActiveApplicationToggleShortcut(
            from: userDefaults
        )

        if storedPausedUntil != nil && pausedUntil == nil {
            userDefaults.removeObject(forKey: Self.hotKeysPausedUntilKey)
        }

        self.windowManagementModel.onShortcutConfigurationChanged = { [weak self] in
            self?.registerHotKeys()
        }

        refreshDockItems()
        registerHotKeys()
        schedulePauseExpiration()
        observeInputSourceChanges()
        observeAppReopenRequests()
        observeApplicationActivations()
    }

    deinit {
        if let inputSourceObserver {
            DistributedNotificationCenter.default().removeObserver(inputSourceObserver)
        }
        if let appReopenObserver {
            NotificationCenter.default.removeObserver(appReopenObserver)
        }
        if let applicationActivationObserver {
            workspaceNotificationCenter.removeObserver(applicationActivationObserver)
        }
        pauseScheduler.cancel()
    }

    var areHotKeysPaused: Bool {
        isPausedIndefinitely || pausedUntil.map { $0 > now() } == true
    }

    var isActiveApplicationDisabled: Bool {
        guard let bundleIdentifier = activeApplication?.bundleIdentifier else { return false }
        return disabledApplications[bundleIdentifier] != nil
    }

    func pauseHotKeys(for duration: TimeInterval) {
        guard duration > 0 else { return }
        isPausedIndefinitely = false
        pausedUntil = now().addingTimeInterval(duration)
        persistPauseState()
        registerHotKeys()
        schedulePauseExpiration()
    }

    func pauseHotKeysIndefinitely() {
        pausedUntil = nil
        isPausedIndefinitely = true
        persistPauseState()
        pauseScheduler.cancel()
        registerHotKeys()
    }

    func resumeHotKeys() {
        guard isPausedIndefinitely || pausedUntil != nil else { return }
        pausedUntil = nil
        isPausedIndefinitely = false
        persistPauseState()
        pauseScheduler.cancel()
        registerHotKeys()
    }

    @discardableResult
    func toggleHotKeys(
        for application: ActiveApplication?
    ) -> ActiveApplicationToggleOutcome {
        guard let application else {
            return .noActiveApplication
        }

        activeApplication = application
        let outcome: ActiveApplicationToggleOutcome
        if disabledApplications[application.bundleIdentifier] != nil {
            disabledApplications.removeValue(forKey: application.bundleIdentifier)
            outcome = .enabled(application)
        } else {
            disabledApplications[application.bundleIdentifier] = application.name
            outcome = .disabled(application)
        }

        userDefaults.set(disabledApplications, forKey: Self.disabledApplicationsKey)
        registerHotKeys()
        return outcome
    }

    @discardableResult
    func toggleHotKeysForActiveApplication() -> ActiveApplicationToggleOutcome {
        toggleHotKeys(for: activeApplicationProvider())
    }

    func handleActiveApplicationToggleHotKey() {
        let generation = beginShortcutHUDRequest()
        let display = shortcutHUDScreenResolver.resolveScreenBeforeAction()
        let application = activeApplicationProvider()
        let outcome = toggleHotKeys(for: application)
        guard generation == shortcutHUDRequestGeneration else { return }

        let payload: ShortcutHUDPayload
        switch outcome {
        case let .disabled(application):
            payload = .appHotKeys(
                action: .appHotKeysDisabled,
                application: application
            )
        case let .enabled(application):
            payload = .appHotKeys(
                action: .appHotKeysEnabled,
                application: application
            )
        case .noActiveApplication:
            return
        }
        shortcutHUDPresenter.present(payload, on: display)
    }

    func refreshDockItems() {
        dockItems = dockItemProvider.currentDockItems()
    }

    func setModifier(_ modifier: ShortcutModifier, isEnabled: Bool) {
        if isEnabled {
            selectedModifiers.insert(modifier)
        } else {
            selectedModifiers.remove(modifier)
        }
    }

    func setActiveApplicationToggleShortcut(
        keyCode: UInt32,
        keyDisplayName: String,
        modifiers: Set<ShortcutModifier>
    ) {
        guard !modifiers.isEmpty else { return }

        activeApplicationToggleShortcut = ActiveApplicationToggleShortcut(
            keyCode: keyCode,
            keyDisplayName: keyDisplayName,
            modifiers: modifiers
        )
        persistActiveApplicationToggleShortcut()
        registerHotKeys()
    }

    func clearActiveApplicationToggleShortcut() {
        activeApplicationToggleShortcut = .unset
        userDefaults.removeObject(forKey: Self.activeApplicationToggleShortcutKey)
        registerHotKeys()
    }

    func dockItem(for key: NumberKey) -> DockItem? {
        guard dockItems.indices.contains(key.dockIndex) else { return nil }
        return dockItems[key.dockIndex]
    }

    func shortcutTitle(for key: NumberKey) -> String {
        let prefix = ShortcutModifier.allCases
            .filter(selectedModifiers.contains)
            .map(\.symbol)
            .joined()
        return "\(prefix)\(key.displayName)"
    }

    var finderShortcutTitle: String {
        "⌥\(finderShortcutKeyTitle)"
    }

    var finderShortcutKeyTitle: String {
        ShortcutKeyDisplay.displayName(forKeyCode: 50)
    }

    func resolveDockItem(for key: NumberKey) -> DockItem? {
        refreshDockItems()
        return dockItem(for: key)
    }

    func activateDockItem(
        _ item: DockItem,
        completion: @escaping (AppLaunchOutcome) -> Void
    ) {
        appLauncher.activateOrLaunch(item, completion: completion)
    }

    func activateDockItemFromMenu(for key: NumberKey) {
        guard let item = resolveDockItem(for: key) else {
            beep()
            return
        }
        activateDockItem(item) { _ in }
    }

    func handleDockHotKey(_ key: NumberKey) {
        let generation = beginShortcutHUDRequest()
        let display = shortcutHUDScreenResolver.resolveScreenBeforeAction()
        guard let item = resolveDockItem(for: key) else {
            beep()
            return
        }

        activateDockItem(item) { [weak self] outcome in
            guard let self,
                  generation == self.shortcutHUDRequestGeneration,
                  outcome == .activated || outcome == .launched else {
                return
            }
            let application = ShortcutHUDApplication(
                item: item,
                localizedDisplayName: self.shortcutHUDLocalizedDisplayName
            )
            let payload = ShortcutHUDPayload.appActivated(
                application: application
            )
            self.shortcutHUDPresenter.present(payload, on: display)
        }
    }

    func handleFinderHotKey() {
        let generation = beginShortcutHUDRequest()
        let display = shortcutHUDScreenResolver.resolveScreenBeforeAction()

        appLauncher.activateFinder { [weak self] outcome in
            guard let self,
                  generation == self.shortcutHUDRequestGeneration,
                  outcome == .activated || outcome == .launched else {
                return
            }
            let payload = ShortcutHUDPayload.appActivated(
                application: .finder
            )
            self.shortcutHUDPresenter.present(payload, on: display)
        }
    }

    func activateFinder() {
        appLauncher.activateFinder { _ in }
    }

    func addManualShortcut(appURL: URL) {
        let bundle = Bundle(url: appURL)
        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
        let name = displayName ?? bundleName ?? appURL.deletingPathExtension().lastPathComponent

        manualShortcuts.append(ManualShortcut(
            name: name,
            url: appURL,
            bundleIdentifier: bundle?.bundleIdentifier
        ))
    }

    func removeManualShortcut(id: UUID) {
        manualShortcuts.removeAll { $0.id == id }
    }

    func setManualShortcut(id: UUID, keyCode: UInt32, keyDisplayName: String, modifiers: Set<ShortcutModifier>) {
        guard !modifiers.isEmpty,
              let index = manualShortcuts.firstIndex(where: { $0.id == id }) else {
            return
        }

        manualShortcuts[index].keyCode = keyCode
        manualShortcuts[index].keyDisplayName = keyDisplayName
        manualShortcuts[index].modifiers = modifiers
        manualShortcuts[index].isEnabled = true
    }

    func setManualShortcutEnabled(id: UUID, isEnabled: Bool) {
        guard let index = manualShortcuts.firstIndex(where: { $0.id == id }) else { return }
        manualShortcuts[index].isEnabled = isEnabled && manualShortcuts[index].shortcutTitle != nil
    }

    func activateManualShortcut(id: UUID) {
        guard let shortcut = manualShortcuts.first(where: { $0.id == id }) else {
            beep()
            return
        }
        activateDockItem(shortcut.dockItem) { _ in }
    }

    var activeManualShortcuts: [ManualShortcut] {
        manualShortcuts.filter(\.canRegister)
    }

    private func beginShortcutHUDRequest() -> Int {
        shortcutHUDRequestGeneration += 1
        return shortcutHUDRequestGeneration
    }

    private func registerHotKeys() {
        if areHotKeysPaused {
            hotKeyService.unregister()
            return
        }

        let scope: GlobalHotKeyRegistrationScope = isActiveApplicationDisabled
            ? .activeApplicationToggleOnly
            : .all

        registrationError = hotKeyService.register(
            modifiers: selectedModifiers,
            finderShortcutEnabled: isFinderShortcutEnabled,
            manualShortcuts: manualShortcuts,
            windowShortcuts: windowManagementModel.windowShortcutsForRegistration,
            activeApplicationToggleShortcut: activeApplicationToggleShortcut,
            scope: scope
        )
    }

    private func persistPauseState() {
        userDefaults.set(isPausedIndefinitely, forKey: Self.hotKeysPausedIndefinitelyKey)
        if let pausedUntil {
            userDefaults.set(pausedUntil, forKey: Self.hotKeysPausedUntilKey)
        } else {
            userDefaults.removeObject(forKey: Self.hotKeysPausedUntilKey)
        }
    }

    private func schedulePauseExpiration() {
        pauseScheduler.cancel()
        guard !isPausedIndefinitely, let pausedUntil else { return }
        let interval = pausedUntil.timeIntervalSince(now())
        guard interval > 0 else {
            resumeHotKeys()
            return
        }
        pauseScheduler.schedule(after: interval) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.pausedUntil == pausedUntil else { return }
                self.resumeHotKeys()
            }
        }
    }

    private func observeApplicationActivations() {
        applicationActivationObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasDisabled = self.isActiveApplicationDisabled
                if let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   let bundleIdentifier = application.bundleIdentifier {
                    self.activeApplication = ActiveApplication(
                        name: application.localizedName ?? bundleIdentifier,
                        bundleIdentifier: bundleIdentifier
                    )
                } else {
                    self.activeApplication = self.activeApplicationProvider()
                }
                if wasDisabled != self.isActiveApplicationDisabled {
                    self.registerHotKeys()
                }
            }
        }
    }

    private func observeInputSourceChanges() {
        inputSourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.inputSourceRevision += 1
            }
        }
    }

    private func observeAppReopenRequests() {
        appReopenObserver = NotificationCenter.default.addObserver(
            forName: .zapApplicationShouldOpenSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                SettingsWindowPresenter.open(
                    model: self,
                    updateService: updateService,
                    showMenuBarIcon: Binding(
                        get: { UserDefaults.standard.object(forKey: "show_menu_bar_icon") as? Bool ?? true },
                        set: { newValue in
                            UserDefaults.standard.set(newValue, forKey: "show_menu_bar_icon")
                            AppActivationPolicy.apply(showMenuBarIcon: newValue)
                        }
                    )
                )
            }
        }
    }

    private func updateLoginItem() {
        do {
            try loginItemService.setStartAtLoginEnabled(startAtLogin)
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
    }

    private func persistModifiers() {
        let rawValues = selectedModifiers.map(\.rawValue).sorted()
        UserDefaults.standard.set(rawValues, forKey: Self.modifiersKey)
    }

    private func persistManualShortcuts() {
        guard let data = try? JSONEncoder().encode(manualShortcuts) else { return }
        UserDefaults.standard.set(data, forKey: Self.manualShortcutsKey)
    }

    private func persistActiveApplicationToggleShortcut() {
        guard let data = try? JSONEncoder().encode(activeApplicationToggleShortcut) else {
            return
        }

        userDefaults.set(data, forKey: Self.activeApplicationToggleShortcutKey)
    }

    private static func loadActiveApplicationToggleShortcut(
        from userDefaults: UserDefaults
    ) -> ActiveApplicationToggleShortcut {
        guard let storedValue = userDefaults.object(
            forKey: activeApplicationToggleShortcutKey
        ) else {
            return .unset
        }

        guard let data = storedValue as? Data else {
            userDefaults.removeObject(forKey: activeApplicationToggleShortcutKey)
            return .unset
        }

        guard let shortcut = try? JSONDecoder().decode(
            ActiveApplicationToggleShortcut.self,
            from: data
        ), shortcut.canRegister else {
            userDefaults.removeObject(forKey: activeApplicationToggleShortcutKey)
            return .unset
        }

        return shortcut
    }

    private static func loadModifiers() -> Set<ShortcutModifier> {
        guard let rawValues = UserDefaults.standard.stringArray(forKey: modifiersKey) else {
            return ShortcutModifier.defaultSelection
        }

        let modifiers = Set(rawValues.compactMap(ShortcutModifier.init(rawValue:)))
        return modifiers.isEmpty ? ShortcutModifier.defaultSelection : modifiers
    }

    private static func loadManualShortcuts() -> [ManualShortcut] {
        guard let data = UserDefaults.standard.data(forKey: manualShortcutsKey),
              let shortcuts = try? JSONDecoder().decode([ManualShortcut].self, from: data) else {
            return []
        }
        return shortcuts
    }

    private static let modifiersKey = "shortcut_modifiers"
    private static let finderShortcutEnabledKey = "finder_shortcut_enabled"
    private static let manualShortcutsKey = "manual_shortcuts"
    private static let startAtLoginKey = "start_at_login"
    private static let hotKeysPausedUntilKey = "hot_keys_paused_until"
    private static let hotKeysPausedIndefinitelyKey = "hot_keys_paused_indefinitely"
    private static let disabledApplicationsKey = "disabled_hot_key_applications"
    private static let activeApplicationToggleShortcutKey =
        "active_application_toggle_shortcut"
}
