public enum WindowShortcutDefaults {
    public static let cKeyCode: UInt32 = 8
    public static let fKeyCode: UInt32 = 3
    public static let zKeyCode: UInt32 = 6
    public static let leftArrowKeyCode: UInt32 = 123
    public static let rightArrowKeyCode: UInt32 = 124
    public static let downArrowKeyCode: UInt32 = 125
    public static let upArrowKeyCode: UInt32 = 126

    public static let all: [WindowShortcut] = [
        shortcut(.center, cKeyCode, "C", [.option, .command]),
        shortcut(.fullscreen, fKeyCode, "F", [.option, .command]),
        shortcut(.leftHalf, leftArrowKeyCode, "←", [.option, .command]),
        shortcut(.rightHalf, rightArrowKeyCode, "→", [.option, .command]),
        shortcut(.topHalf, upArrowKeyCode, "↑", [.option, .command]),
        shortcut(.bottomHalf, downArrowKeyCode, "↓", [.option, .command]),
        shortcut(.upperLeft, leftArrowKeyCode, "←", [.control, .command]),
        shortcut(.upperRight, rightArrowKeyCode, "→", [.control, .command]),
        shortcut(.lowerLeft, leftArrowKeyCode, "←", [.control, .shift, .command]),
        shortcut(.lowerRight, rightArrowKeyCode, "→", [.control, .shift, .command]),
        shortcut(.nextDisplay, rightArrowKeyCode, "→", [.control, .option, .command]),
        shortcut(.previousDisplay, leftArrowKeyCode, "←", [.control, .option, .command]),
        shortcut(.nextThird, rightArrowKeyCode, "→", [.control, .option]),
        shortcut(.previousThird, leftArrowKeyCode, "←", [.control, .option]),
        shortcut(.larger, rightArrowKeyCode, "→", [.control, .option, .shift]),
        shortcut(.smaller, leftArrowKeyCode, "←", [.control, .option, .shift]),
        shortcut(.undo, zKeyCode, "Z", [.option, .command]),
        shortcut(.redo, zKeyCode, "Z", [.option, .shift, .command])
    ]

    public static func shortcut(for action: WindowAction) -> WindowShortcut {
        guard let value = all.first(where: { $0.action == action }) else {
            preconditionFailure("Missing default window shortcut for \(action.rawValue)")
        }
        return value
    }

    private static func shortcut(
        _ action: WindowAction,
        _ keyCode: UInt32,
        _ keyDisplayName: String,
        _ modifiers: Set<ShortcutModifier>
    ) -> WindowShortcut {
        WindowShortcut(
            action: action,
            keyCode: keyCode,
            keyDisplayName: keyDisplayName,
            modifiers: modifiers,
            isEnabled: true
        )
    }
}
