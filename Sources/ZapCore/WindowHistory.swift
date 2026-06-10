import CoreGraphics

public struct WindowHistoryItem: Equatable, Sendable {
    public let applicationIdentifier: String
    public let windowFrame: CGRect

    public init(applicationIdentifier: String, windowFrame: CGRect) {
        self.applicationIdentifier = applicationIdentifier
        self.windowFrame = windowFrame
    }
}

public struct WindowHistory: Equatable, Sendable {
    private let maximumUndoCount = 50
    private var undoStacks: [String: [WindowHistoryItem]]
    private var redoStacks: [String: [WindowHistoryItem]]

    public init() {
        undoStacks = [:]
        redoStacks = [:]
    }

    public func canUndo(applicationIdentifier: String) -> Bool {
        !(undoStacks[applicationIdentifier]?.isEmpty ?? true)
    }

    public func canRedo(applicationIdentifier: String) -> Bool {
        !(redoStacks[applicationIdentifier]?.isEmpty ?? true)
    }

    public mutating func record(applicationIdentifier: String, frame: CGRect) {
        let item = WindowHistoryItem(applicationIdentifier: applicationIdentifier, windowFrame: frame)
        if undoStacks[applicationIdentifier]?.last != item {
            undoStacks[applicationIdentifier, default: []].append(item)
            if undoStacks[applicationIdentifier, default: []].count > maximumUndoCount {
                undoStacks[applicationIdentifier]?.removeFirst()
            }
        }
        redoStacks[applicationIdentifier] = []
    }

    public mutating func undo(applicationIdentifier: String, currentFrame: CGRect) -> WindowHistoryItem? {
        guard var stack = undoStacks[applicationIdentifier], let item = stack.popLast() else {
            return nil
        }

        undoStacks[applicationIdentifier] = stack
        redoStacks[applicationIdentifier, default: []].append(WindowHistoryItem(
            applicationIdentifier: applicationIdentifier,
            windowFrame: currentFrame
        ))
        return item
    }

    public mutating func redo(applicationIdentifier: String, currentFrame: CGRect) -> WindowHistoryItem? {
        guard var stack = redoStacks[applicationIdentifier], let item = stack.popLast() else {
            return nil
        }

        redoStacks[applicationIdentifier] = stack
        undoStacks[applicationIdentifier, default: []].append(WindowHistoryItem(
            applicationIdentifier: applicationIdentifier,
            windowFrame: currentFrame
        ))
        return item
    }
}
