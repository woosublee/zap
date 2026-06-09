public struct WindowShortcut: Codable, Equatable, Identifiable, Sendable {
    public var action: WindowAction
    public var keyCode: UInt32?
    public var keyDisplayName: String?
    public var modifiers: Set<ShortcutModifier>
    public var isEnabled: Bool

    public var id: String { action.id }

    public init(
        action: WindowAction,
        keyCode: UInt32?,
        keyDisplayName: String?,
        modifiers: Set<ShortcutModifier>,
        isEnabled: Bool
    ) {
        self.action = action
        self.keyCode = keyCode
        self.keyDisplayName = keyDisplayName
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }

    public var canRegister: Bool {
        isEnabled && keyCode != nil && !modifiers.isEmpty
    }

    public var shortcutTitle: String? {
        guard keyCode != nil, let keyDisplayName, !modifiers.isEmpty else { return nil }
        let modifierSymbols = modifiers
            .sorted { $0.windowShortcutDisplayOrder < $1.windowShortcutDisplayOrder }
            .map(\.symbol)
            .joined()
        return modifierSymbols + keyDisplayName
    }

    public var displayText: String {
        guard isEnabled else { return "Off" }
        return shortcutTitle ?? "Off"
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
