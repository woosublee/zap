import Foundation
import SwiftUI
import ZapCore

protocol WindowActionPerforming {
    func perform(action: WindowAction) -> WindowManagementResult
}

protocol WindowShortcutStoring: AnyObject {
    func loadWindowShortcuts() -> [WindowShortcut]
    func saveWindowShortcuts(_ shortcuts: [WindowShortcut])
}

protocol WindowManagementSettingsStoring: AnyObject {
    func loadWindowManagementEnabled() -> Bool
    func saveWindowManagementEnabled(_ isEnabled: Bool)
}

extension WindowManagementService: WindowActionPerforming {}

@MainActor
final class WindowManagementModel: ObservableObject {
    @Published private(set) var windowShortcuts: [WindowShortcut]
    @Published private(set) var accessibilityTrusted: Bool
    @Published private(set) var windowManagementError: String?
    @Published private(set) var shortcutRegistrationError: String?
    @Published private(set) var isShortcutRecordingActive: Bool
    @Published var isWindowManagementEnabled: Bool

    var onShortcutConfigurationChanged: (() -> Void)?

    private let service: WindowActionPerforming
    private let permissionService: AccessibilityPermissionChecking
    private let settingsOpener: SystemSettingsOpening
    private let shortcutStore: WindowShortcutStoring
    private let settingsStore: WindowManagementSettingsStoring

    init(
        service: WindowActionPerforming = WindowManagementService(history: DefaultWindowHistoryRecorder()),
        permissionService: AccessibilityPermissionChecking = AccessibilityPermissionService(),
        settingsOpener: SystemSettingsOpening = SystemSettingsOpener(),
        shortcutStore: WindowShortcutStoring = UserDefaultsWindowShortcutStore(),
        settingsStore: WindowManagementSettingsStoring = UserDefaultsWindowManagementSettingsStore(),
        isWindowManagementEnabled: Bool? = nil
    ) {
        self.service = service
        self.permissionService = permissionService
        self.settingsOpener = settingsOpener
        self.shortcutStore = shortcutStore
        self.settingsStore = settingsStore
        self.windowShortcuts = shortcutStore.loadWindowShortcuts()
        self.accessibilityTrusted = permissionService.isTrusted
        self.windowManagementError = nil
        self.shortcutRegistrationError = nil
        self.isShortcutRecordingActive = false
        self.isWindowManagementEnabled = isWindowManagementEnabled ?? settingsStore.loadWindowManagementEnabled()
    }

    var windowShortcutsForRegistration: [WindowShortcut] {
        guard isWindowManagementEnabled, !isShortcutRecordingActive else { return [] }
        return windowShortcuts.filter(\.canRegister)
    }

    @discardableResult
    func perform(action: WindowAction) -> WindowManagementResult {
        let result = service.perform(action: action)
        switch result {
        case .success:
            windowManagementError = nil
        case let .failure(error):
            windowManagementError = String(describing: error)
        }
        return result
    }

    func setWindowManagementEnabled(_ isEnabled: Bool) {
        isWindowManagementEnabled = isEnabled
        settingsStore.saveWindowManagementEnabled(isEnabled)
        notifyShortcutConfigurationChanged()
    }

    func setShortcutRecordingActive(_ isActive: Bool) {
        guard isShortcutRecordingActive != isActive else { return }
        isShortcutRecordingActive = isActive
        notifyShortcutConfigurationChanged()
    }

    func setShortcut(action: WindowAction, keyCode: UInt32, keyDisplayName: String, modifiers: Set<ShortcutModifier>) {
        guard !modifiers.isEmpty else {
            shortcutRegistrationError = "Select at least one modifier key."
            return
        }
        shortcutRegistrationError = nil
        windowManagementError = nil
        updateShortcut(action: action) { shortcut in
            shortcut.keyCode = keyCode
            shortcut.keyDisplayName = keyDisplayName
            shortcut.modifiers = modifiers
            shortcut.isEnabled = true
        }
    }

    func setShortcutEnabled(action: WindowAction, isEnabled: Bool) {
        shortcutRegistrationError = nil
        updateShortcut(action: action) { shortcut in
            shortcut.isEnabled = isEnabled && shortcut.shortcutTitle != nil
        }
    }

    func resetShortcutsToDefaults() {
        shortcutRegistrationError = nil
        windowShortcuts = WindowShortcutDefaults.all
        persistAndNotify()
    }

    func requestAccessibilityPermission() {
        permissionService.requestPrompt()
    }

    func refreshAccessibilityPermission() {
        accessibilityTrusted = permissionService.isTrusted
    }

    @discardableResult
    func openAccessibilitySettings() -> Bool {
        settingsOpener.openAccessibilitySettings()
    }

    private func updateShortcut(action: WindowAction, update: (inout WindowShortcut) -> Void) {
        guard let index = windowShortcuts.firstIndex(where: { $0.action == action }) else { return }
        update(&windowShortcuts[index])
        persistAndNotify()
    }

    private func persistAndNotify() {
        shortcutStore.saveWindowShortcuts(windowShortcuts)
        notifyShortcutConfigurationChanged()
    }

    private func notifyShortcutConfigurationChanged() {
        onShortcutConfigurationChanged?()
    }
}

final class UserDefaultsWindowShortcutStore: WindowShortcutStoring {
    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults = .standard, key: String = "window_shortcuts") {
        self.userDefaults = userDefaults
        self.key = key
    }

    func loadWindowShortcuts() -> [WindowShortcut] {
        guard let data = userDefaults.data(forKey: key),
              let shortcuts = try? JSONDecoder().decode([WindowShortcut].self, from: data),
              !shortcuts.isEmpty else {
            return WindowShortcutDefaults.all
        }
        return mergedWithDefaults(shortcuts)
    }

    func saveWindowShortcuts(_ shortcuts: [WindowShortcut]) {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        userDefaults.set(data, forKey: key)
    }

    private func mergedWithDefaults(_ stored: [WindowShortcut]) -> [WindowShortcut] {
        WindowAction.allCases.map { action in
            stored.first { $0.action == action } ?? WindowShortcutDefaults.shortcut(for: action)
        }
    }
}

final class UserDefaultsWindowManagementSettingsStore: WindowManagementSettingsStoring {
    private let userDefaults: UserDefaults
    private let enabledKey: String

    init(userDefaults: UserDefaults = .standard, enabledKey: String = "window_management_enabled") {
        self.userDefaults = userDefaults
        self.enabledKey = enabledKey
    }

    func loadWindowManagementEnabled() -> Bool {
        guard userDefaults.object(forKey: enabledKey) != nil else { return true }
        return userDefaults.bool(forKey: enabledKey)
    }

    func saveWindowManagementEnabled(_ isEnabled: Bool) {
        userDefaults.set(isEnabled, forKey: enabledKey)
    }
}
