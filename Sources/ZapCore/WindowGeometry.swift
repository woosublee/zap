import CoreGraphics

public struct DisplayFrame: Equatable, Sendable {
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let isMain: Bool

    public init(frame: CGRect, visibleFrame: CGRect, isMain: Bool) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.isMain = isMain
    }
}

public struct DisplayContext: Equatable, Sendable {
    public let source: DisplayFrame
    public let destination: DisplayFrame

    public init(source: DisplayFrame, destination: DisplayFrame) {
        self.source = source
        self.destination = destination
    }

    public var sourceVisibleFrame: CGRect { source.visibleFrame }
    public var destinationVisibleFrame: CGRect { destination.visibleFrame }
}

public struct WindowCalculationInput: Equatable, Sendable {
    public let windowFrame: CGRect
    public let sourceVisibleFrame: CGRect
    public let destinationVisibleFrame: CGRect
    public let action: WindowAction

    public init(
        windowFrame: CGRect,
        sourceVisibleFrame: CGRect,
        destinationVisibleFrame: CGRect,
        action: WindowAction
    ) {
        self.windowFrame = windowFrame
        self.sourceVisibleFrame = sourceVisibleFrame
        self.destinationVisibleFrame = destinationVisibleFrame
        self.action = action
    }
}

public struct WindowCalculationResult: Equatable, Sendable {
    public let frame: CGRect
    public let resolvedAction: WindowAction

    public init(frame: CGRect, resolvedAction: WindowAction) {
        self.frame = frame
        self.resolvedAction = resolvedAction
    }
}

public enum WindowDomainError: Error, Equatable, Sendable {
    case noDisplays
    case unsupportedDisplayAction(WindowAction)
}
