import AppKit
import Foundation
import ZapCore

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

    private var inputSourceObserver: NSObjectProtocol?
    private var appReopenObserver: NSObjectProtocol?

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
    private lazy var hotKeyService = GlobalHotKeyService(
        onDockHotKey: { [weak self] key in
            Task { @MainActor [weak self] in
                self?.activateDockItem(for: key)
            }
        },
        onFinderHotKey: { [weak self] in
            Task { @MainActor [weak self] in
                self?.activateFinder()
            }
        },
        onManualHotKey: { [weak self] id in
            Task { @MainActor [weak self] in
                self?.activateManualShortcut(id: id)
            }
        }
    )

    init(
        dockItemProvider: any DockItemProviding = DockItemProvider(),
        appLauncher: any AppLaunching = AppLauncher(),
        loginItemService: any LoginItemControlling = LoginItemService()
    ) {
        self.dockItemProvider = dockItemProvider
        self.appLauncher = appLauncher
        self.loginItemService = loginItemService
        self.manualShortcuts = Self.loadManualShortcuts()
        self.isFinderShortcutEnabled = UserDefaults.standard.bool(forKey: Self.finderShortcutEnabledKey)
        self.selectedModifiers = Self.loadModifiers()
        self.startAtLogin = UserDefaults.standard.bool(forKey: Self.startAtLoginKey)

        refreshDockItems()
        registerHotKeys()
        observeInputSourceChanges()
        observeAppReopenRequests()
    }

    deinit {
        if let inputSourceObserver {
            DistributedNotificationCenter.default().removeObserver(inputSourceObserver)
        }
        if let appReopenObserver {
            NotificationCenter.default.removeObserver(appReopenObserver)
        }
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

    func activateDockItem(for key: NumberKey) {
        refreshDockItems()
        guard let item = dockItem(for: key) else {
            NSSound.beep()
            return
        }
        appLauncher.activateOrLaunch(item)
    }

    func activateFinder() {
        appLauncher.activateFinder()
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
            NSSound.beep()
            return
        }
        appLauncher.activateOrLaunch(shortcut.dockItem)
    }

    var activeManualShortcuts: [ManualShortcut] {
        manualShortcuts.filter(\.canRegister)
    }

    private func registerHotKeys() {
        registrationError = hotKeyService.register(
            modifiers: selectedModifiers,
            finderShortcutEnabled: isFinderShortcutEnabled,
            manualShortcuts: manualShortcuts
        )
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
                SettingsWindowPresenter.open(model: self)
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
}
