public enum WindowActionCategory: String, CaseIterable, Codable, Equatable, Sendable {
    case positioning
    case display
    case sizing
    case history
}

public enum WindowAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case center
    case fullscreen
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case upperLeft
    case upperRight
    case lowerLeft
    case lowerRight
    case nextDisplay
    case previousDisplay
    case nextThird
    case previousThird
    case larger
    case smaller
    case undo
    case redo

    public var id: String { rawValue }

    public var title: String { displayName }

    public var displayName: String {
        switch self {
        case .center: "Center"
        case .fullscreen: "Fullscreen"
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .upperLeft: "Upper Left"
        case .upperRight: "Upper Right"
        case .lowerLeft: "Lower Left"
        case .lowerRight: "Lower Right"
        case .nextDisplay: "Next Display"
        case .previousDisplay: "Previous Display"
        case .nextThird: "Next Third"
        case .previousThird: "Previous Third"
        case .larger: "Larger"
        case .smaller: "Smaller"
        case .undo: "Undo"
        case .redo: "Redo"
        }
    }

    public var category: WindowActionCategory {
        switch self {
        case .center, .fullscreen, .leftHalf, .rightHalf, .topHalf, .bottomHalf,
             .upperLeft, .upperRight, .lowerLeft, .lowerRight:
            .positioning
        case .nextDisplay, .previousDisplay:
            .display
        case .nextThird, .previousThird, .larger, .smaller:
            .sizing
        case .undo, .redo:
            .history
        }
    }
}
