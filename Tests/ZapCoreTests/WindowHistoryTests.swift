import CoreGraphics
import XCTest
@testable import ZapCore

final class WindowHistoryTests: XCTestCase {
    func testRecordEnablesUndoForApplicationIdentifier() {
        var history = WindowHistory()
        let frame = CGRect(x: 10, y: 20, width: 300, height: 400)

        history.record(applicationIdentifier: "com.example.Terminal", frame: frame)

        XCTAssertTrue(history.canUndo(applicationIdentifier: "com.example.Terminal"))
        XCTAssertFalse(history.canRedo(applicationIdentifier: "com.example.Terminal"))
    }

    func testUndoReturnsLastFrameAndStoresCurrentFrameForRedo() {
        var history = WindowHistory()
        let previous = CGRect(x: 10, y: 20, width: 300, height: 400)
        let current = CGRect(x: 0, y: 25, width: 1440, height: 875)

        history.record(applicationIdentifier: "com.example.Terminal", frame: previous)
        let undoItem = history.undo(applicationIdentifier: "com.example.Terminal", currentFrame: current)

        XCTAssertEqual(undoItem, WindowHistoryItem(applicationIdentifier: "com.example.Terminal", windowFrame: previous))
        XCTAssertFalse(history.canUndo(applicationIdentifier: "com.example.Terminal"))
        XCTAssertTrue(history.canRedo(applicationIdentifier: "com.example.Terminal"))
    }

    func testRedoReturnsFrameCapturedDuringUndo() {
        var history = WindowHistory()
        let previous = CGRect(x: 10, y: 20, width: 300, height: 400)
        let current = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let afterUndo = previous

        history.record(applicationIdentifier: "com.example.Terminal", frame: previous)
        _ = history.undo(applicationIdentifier: "com.example.Terminal", currentFrame: current)
        let redoItem = history.redo(applicationIdentifier: "com.example.Terminal", currentFrame: afterUndo)

        XCTAssertEqual(redoItem, WindowHistoryItem(applicationIdentifier: "com.example.Terminal", windowFrame: current))
        XCTAssertTrue(history.canUndo(applicationIdentifier: "com.example.Terminal"))
        XCTAssertFalse(history.canRedo(applicationIdentifier: "com.example.Terminal"))
    }

    func testRecordClearsRedoStackForThatApplicationOnly() {
        var history = WindowHistory()
        history.record(applicationIdentifier: "com.example.Terminal", frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        history.record(applicationIdentifier: "com.example.Browser", frame: CGRect(x: 50, y: 50, width: 200, height: 200))
        _ = history.undo(applicationIdentifier: "com.example.Terminal", currentFrame: CGRect(x: 10, y: 10, width: 100, height: 100))
        _ = history.undo(applicationIdentifier: "com.example.Browser", currentFrame: CGRect(x: 60, y: 60, width: 200, height: 200))

        history.record(applicationIdentifier: "com.example.Terminal", frame: CGRect(x: 20, y: 20, width: 100, height: 100))

        XCTAssertFalse(history.canRedo(applicationIdentifier: "com.example.Terminal"))
        XCTAssertTrue(history.canRedo(applicationIdentifier: "com.example.Browser"))
    }

    func testHistoryIsIsolatedByApplicationIdentifier() {
        var history = WindowHistory()
        let terminalFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let browserFrame = CGRect(x: 200, y: 200, width: 500, height: 500)

        history.record(applicationIdentifier: "com.example.Terminal", frame: terminalFrame)
        history.record(applicationIdentifier: "com.example.Browser", frame: browserFrame)

        XCTAssertEqual(history.undo(applicationIdentifier: "com.example.Browser", currentFrame: .zero)?.windowFrame, browserFrame)
        XCTAssertEqual(history.undo(applicationIdentifier: "com.example.Terminal", currentFrame: .zero)?.windowFrame, terminalFrame)
    }

    func testRecordingSameFrameConsecutivelyDoesNotDuplicateUndoEntry() {
        var history = WindowHistory()
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        history.record(applicationIdentifier: "com.example.Terminal", frame: frame)
        history.record(applicationIdentifier: "com.example.Terminal", frame: frame)
        _ = history.undo(applicationIdentifier: "com.example.Terminal", currentFrame: .zero)

        XCTAssertFalse(history.canUndo(applicationIdentifier: "com.example.Terminal"))
    }

    func testUndoStackKeepsMostRecentFiftyEntriesPerApplicationLikeSpectacle() {
        var history = WindowHistory()
        let app = "com.example.Terminal"
        for index in 0..<51 {
            history.record(applicationIdentifier: app, frame: CGRect(x: index, y: 0, width: 100, height: 100))
        }

        var undoFrames: [CGRect] = []
        while let item = history.undo(applicationIdentifier: app, currentFrame: .zero) {
            undoFrames.append(item.windowFrame)
        }

        XCTAssertEqual(undoFrames.count, 50)
        XCTAssertEqual(undoFrames.last, CGRect(x: 1, y: 0, width: 100, height: 100))
    }
}
