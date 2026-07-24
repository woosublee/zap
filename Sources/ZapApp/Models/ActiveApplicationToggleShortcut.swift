import Foundation
import ZapCore

struct ActiveApplicationToggleShortcut: Codable, Equatable {
    var keyCode: UInt32?
    var keyDisplayName: String?
    var modifiers: Set<ShortcutModifier>

    static let unset = ActiveApplicationToggleShortcut(
        keyCode: nil,
        keyDisplayName: nil,
        modifiers: []
    )

    var canRegister: Bool {
        keyCode != nil && !modifiers.isEmpty
    }

    var shortcutTitle: String? {
        guard let keyCode, !modifiers.isEmpty else { return nil }

        let modifierSymbols = ShortcutModifier.allCases
            .filter(modifiers.contains)
            .map(\.symbol)
            .joined()

        let key = ShortcutKeyDisplay.displayName(
            forKeyCode: keyCode,
            fallback: keyDisplayName
        )
        return modifierSymbols + key
    }
}
