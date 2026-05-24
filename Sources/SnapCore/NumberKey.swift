public enum NumberKey: Int, CaseIterable, Identifiable, Sendable {
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8
    case nine = 9

    public var id: Int { rawValue }
    public var displayName: String { String(rawValue) }
    public var dockIndex: Int { rawValue - 1 }

    public var carbonKeyCode: UInt32 {
        switch self {
        case .one: 18
        case .two: 19
        case .three: 20
        case .four: 21
        case .five: 23
        case .six: 22
        case .seven: 26
        case .eight: 28
        case .nine: 25
        }
    }

    public static func key(forDockIndex index: Int) -> NumberKey? {
        NumberKey(rawValue: index + 1)
    }
}
