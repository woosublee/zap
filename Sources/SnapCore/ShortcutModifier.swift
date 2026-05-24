public enum ShortcutModifier: String, CaseIterable, Codable, Identifiable, Sendable {
    case command
    case control
    case option
    case shift

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .command: "Command"
        case .control: "Control"
        case .option: "Option"
        case .shift: "Shift"
        }
    }

    public var symbol: String {
        switch self {
        case .command: "⌘"
        case .control: "⌃"
        case .option: "⌥"
        case .shift: "⇧"
        }
    }

    public static let defaultSelection: Set<ShortcutModifier> = [.option]
}
