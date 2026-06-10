import Foundation
import ZapCore

enum WindowShortcutDisplay {
    static func shortcutTitle(
        for shortcut: WindowShortcut,
        keyDisplayName: (UInt32, String?) -> String = ShortcutKeyDisplay.displayName(forKeyCode:fallback:)
    ) -> String? {
        guard let keyCode = shortcut.keyCode, !shortcut.modifiers.isEmpty else { return nil }
        let modifierSymbols = shortcut.modifiers
            .sorted { $0.windowShortcutDisplayOrder < $1.windowShortcutDisplayOrder }
            .map(\.symbol)
            .joined()
        return modifierSymbols + keyDisplayName(keyCode, shortcut.keyDisplayName)
    }
}

private extension ShortcutModifier {
    var windowShortcutDisplayOrder: Int {
        switch self {
        case .control: 0
        case .option: 1
        case .shift: 2
        case .command: 3
        }
    }
}
