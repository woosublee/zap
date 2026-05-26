import Foundation
import ZapCore

struct ManualShortcut: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var url: URL
    var bundleIdentifier: String?
    var keyCode: UInt32?
    var keyDisplayName: String?
    var modifiers: Set<ShortcutModifier>
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        bundleIdentifier: String?,
        keyCode: UInt32? = nil,
        keyDisplayName: String? = nil,
        modifiers: Set<ShortcutModifier> = [],
        isEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.keyCode = keyCode
        self.keyDisplayName = keyDisplayName
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }

    var dockItem: DockItem {
        DockItem(name: name, url: url, bundleIdentifier: bundleIdentifier)
    }

    var canRegister: Bool {
        isEnabled && keyCode != nil && !modifiers.isEmpty
    }

    var shortcutTitle: String? {
        guard let keyCode, !modifiers.isEmpty else { return nil }
        let prefix = ShortcutModifier.allCases
            .filter(modifiers.contains)
            .map(\.symbol)
            .joined()
        let key = ShortcutKeyDisplay.displayName(forKeyCode: keyCode, fallback: keyDisplayName)
        return "\(prefix)\(key)"
    }
}
