import CoreGraphics

public struct ScreenDetector: Sendable {
    public init() {}

    public func overlapArea(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        return intersection.width * intersection.height
    }

    public func sourceDisplay(for windowFrame: CGRect, displays: [DisplayFrame]) throws -> DisplayFrame {
        guard !displays.isEmpty else { throw WindowDomainError.noDisplays }

        let ranked = displays.map { display in
            (display: display, area: overlapArea(windowFrame, display.frame))
        }

        if let match = ranked.max(by: { $0.area < $1.area }), match.area > 0 {
            return match.display
        }

        return displays.first(where: \.isMain) ?? displays[0]
    }

    public func destinationDisplay(
        for action: WindowAction,
        source: DisplayFrame,
        displays: [DisplayFrame]
    ) throws -> DisplayFrame {
        guard !displays.isEmpty else { throw WindowDomainError.noDisplays }
        guard action == .nextDisplay || action == .previousDisplay else {
            throw WindowDomainError.unsupportedDisplayAction(action)
        }

        let ordered = Self.orderedDisplays(displays)
        guard let index = ordered.firstIndex(of: source) else {
            return ordered.first(where: \.isMain) ?? ordered[0]
        }

        switch action {
        case .nextDisplay:
            return ordered[(index + 1) % ordered.count]
        case .previousDisplay:
            return ordered[(index - 1 + ordered.count) % ordered.count]
        default:
            throw WindowDomainError.unsupportedDisplayAction(action)
        }
    }

    public func displayContext(
        for windowFrame: CGRect,
        action: WindowAction,
        displays: [DisplayFrame]
    ) throws -> DisplayContext {
        let source = try sourceDisplay(for: windowFrame, displays: displays)
        let destination: DisplayFrame
        if action == .nextDisplay || action == .previousDisplay {
            destination = try destinationDisplay(for: action, source: source, displays: displays)
        } else {
            destination = source
        }
        return DisplayContext(source: source, destination: destination)
    }

    private static func orderedDisplays(_ displays: [DisplayFrame]) -> [DisplayFrame] {
        displays.sorted { first, second in
            let firstAtOrigin = first.frame.origin == .zero
            let secondAtOrigin = second.frame.origin == .zero
            if firstAtOrigin != secondAtOrigin {
                return firstAtOrigin
            }
            if first.frame.minX != second.frame.minX {
                return first.frame.minX > second.frame.minX
            }
            return first.frame.minY > second.frame.minY
        }
    }
}
