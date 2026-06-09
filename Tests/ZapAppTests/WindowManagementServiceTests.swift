import CoreGraphics
import XCTest
@testable import ZapApp
@testable import ZapCore

final class WindowManagementServiceTests: XCTestCase {
    func testUndoFailsWhenHistoryFrameIsUnavailable() {
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let currentFrame = CGRect(x: 0, y: 25, width: 720, height: 875)
        let windows = MockAccessibilityWindows(frontmostWindow: window)
        windows.frameResult = .success(currentFrame)
        let history = MockWindowHistoryRecorder()
        let feedback = MockFailureFeedback()
        let service = makeService(windows: windows, history: history, feedback: feedback)

        let result = service.perform(action: .undo)

        XCTAssertEqual(result, .failure(.calculationFailed))
        XCTAssertEqual(feedback.failureCount, 1)
        XCTAssertEqual(windows.setFrameCallCount, 0)
        XCTAssertEqual(history.undoRequests, [.init(applicationIdentifier: "com.example.App", currentFrame: currentFrame)])
    }

    func testRedoFailsWhenHistoryFrameIsUnavailable() {
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let currentFrame = CGRect(x: 100, y: 100, width: 500, height: 400)
        let windows = MockAccessibilityWindows(frontmostWindow: window)
        windows.frameResult = .success(currentFrame)
        let history = MockWindowHistoryRecorder()
        let feedback = MockFailureFeedback()
        let service = makeService(windows: windows, history: history, feedback: feedback)

        let result = service.perform(action: .redo)

        XCTAssertEqual(result, .failure(.calculationFailed))
        XCTAssertEqual(feedback.failureCount, 1)
        XCTAssertEqual(windows.setFrameCallCount, 0)
        XCTAssertEqual(history.redoRequests, [.init(applicationIdentifier: "com.example.App", currentFrame: currentFrame)])
    }

    func testUndoSetsHistoryFrameWhenAvailable() {
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let currentFrame = CGRect(x: 0, y: 25, width: 720, height: 875)
        let undoFrame = CGRect(x: 100, y: 100, width: 500, height: 400)
        let windows = MockAccessibilityWindows(frontmostWindow: window)
        windows.frameResults = [.success(currentFrame), .success(undoFrame)]
        let calculator = MockWindowPositionCalculator()
        calculator.calculateHandler = { _ in
            XCTFail("Undo should use history and not calculate a new window position.")
            return nil
        }
        let history = MockWindowHistoryRecorder()
        history.undoItem = WindowHistoryItem(applicationIdentifier: "com.example.App", windowFrame: undoFrame)
        let feedback = MockFailureFeedback()
        let service = makeService(windows: windows, calculator: calculator, history: history, feedback: feedback)

        let result = service.perform(action: .undo)

        XCTAssertEqual(result, .success(action: .undo, frame: undoFrame))
        XCTAssertEqual(feedback.failureCount, 0)
        XCTAssertEqual(windows.capturedSetFrames, [undoFrame])
        XCTAssertEqual(history.undoRequests, [.init(applicationIdentifier: "com.example.App", currentFrame: currentFrame)])
        XCTAssertEqual(history.records.count, 0)
        XCTAssertEqual(calculator.calculateCallCount, 0)
    }

    func testRedoSetsHistoryFrameWhenAvailable() {
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let currentFrame = CGRect(x: 100, y: 100, width: 500, height: 400)
        let redoFrame = CGRect(x: 0, y: 25, width: 720, height: 875)
        let windows = MockAccessibilityWindows(frontmostWindow: window)
        windows.frameResults = [.success(currentFrame), .success(redoFrame)]
        let calculator = MockWindowPositionCalculator()
        calculator.calculateHandler = { _ in
            XCTFail("Redo should use history and not calculate a new window position.")
            return nil
        }
        let history = MockWindowHistoryRecorder()
        history.redoItem = WindowHistoryItem(applicationIdentifier: "com.example.App", windowFrame: redoFrame)
        let feedback = MockFailureFeedback()
        let service = makeService(windows: windows, calculator: calculator, history: history, feedback: feedback)

        let result = service.perform(action: .redo)

        XCTAssertEqual(result, .success(action: .redo, frame: redoFrame))
        XCTAssertEqual(feedback.failureCount, 0)
        XCTAssertEqual(windows.capturedSetFrames, [redoFrame])
        XCTAssertEqual(history.redoRequests, [.init(applicationIdentifier: "com.example.App", currentFrame: currentFrame)])
        XCTAssertEqual(history.records.count, 0)
        XCTAssertEqual(calculator.calculateCallCount, 0)
    }

    func testPerformSetsCalculatedFrameAndRecordsSuccessfulMove() {
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let originalFrame = CGRect(x: 100, y: 100, width: 500, height: 400)
        let targetFrame = CGRect(x: 0, y: 25, width: 720, height: 875)
        let windows = MockAccessibilityWindows(frontmostWindow: window)
        windows.frameResults = [.success(originalFrame), .success(targetFrame)]
        let calculator = MockWindowPositionCalculator(result: WindowCalculationResult(frame: targetFrame, resolvedAction: .leftHalf))
        let history = MockWindowHistoryRecorder()
        let feedback = MockFailureFeedback()
        let service = makeService(windows: windows, calculator: calculator, history: history, feedback: feedback)

        let result = service.perform(action: .leftHalf)

        XCTAssertEqual(result, .success(action: .leftHalf, frame: targetFrame))
        XCTAssertEqual(feedback.failureCount, 0)
        XCTAssertEqual(windows.capturedSetFrames, [targetFrame])
        XCTAssertEqual(history.records, [
            .init(applicationIdentifier: "com.example.App", previousFrame: originalFrame, targetFrame: targetFrame)
        ])
    }

    func testPerformUsesActualFrameAfterSetFrameForSuccessAndHistoryWhenAppConstrainsWindow() {
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let originalFrame = CGRect(x: 100, y: 100, width: 500, height: 400)
        let requestedFrame = CGRect(x: 0, y: 25, width: 720, height: 875)
        let actualFrame = CGRect(x: 0, y: 25, width: 720, height: 700)
        let windows = MockAccessibilityWindows(frontmostWindow: window)
        windows.frameResults = [.success(originalFrame), .success(actualFrame)]
        let calculator = MockWindowPositionCalculator(result: WindowCalculationResult(frame: requestedFrame, resolvedAction: .leftHalf))
        let history = MockWindowHistoryRecorder()
        let feedback = MockFailureFeedback()
        let service = makeService(windows: windows, calculator: calculator, history: history, feedback: feedback)

        let result = service.perform(action: .leftHalf)

        XCTAssertEqual(result, .success(action: .leftHalf, frame: actualFrame))
        XCTAssertEqual(feedback.failureCount, 0)
        XCTAssertEqual(windows.capturedSetFrames, [requestedFrame])
        XCTAssertEqual(windows.frameCallCount, 2)
        XCTAssertEqual(history.records, [
            .init(applicationIdentifier: "com.example.App", previousFrame: originalFrame, targetFrame: actualFrame)
        ])
    }

    func testPerformFailsAndDoesNotRecordWhenActualFrameCannotBeReadAfterSetFrame() {
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let originalFrame = CGRect(x: 100, y: 100, width: 500, height: 400)
        let requestedFrame = CGRect(x: 0, y: 25, width: 720, height: 875)
        let windows = MockAccessibilityWindows(frontmostWindow: window)
        windows.frameResults = [
            .success(originalFrame),
            .failure(AccessibilityWindowError.frameReadFailed(attribute: "kAXPositionAttribute"))
        ]
        let calculator = MockWindowPositionCalculator(result: WindowCalculationResult(frame: requestedFrame, resolvedAction: .leftHalf))
        let history = MockWindowHistoryRecorder()
        let feedback = MockFailureFeedback()
        let service = makeService(windows: windows, calculator: calculator, history: history, feedback: feedback)

        let result = service.perform(action: .leftHalf)

        XCTAssertEqual(result, .failure(.frameReadFailed))
        XCTAssertEqual(feedback.failureCount, 1)
        XCTAssertEqual(windows.capturedSetFrames, [requestedFrame])
        XCTAssertEqual(windows.frameCallCount, 2)
        XCTAssertEqual(history.records.count, 0)
    }

    func testPerformTreatsAlreadyAtCalculatedFrameAsFailureAndDoesNotSetFrameOrRecordHistory() {
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let currentFrame = CGRect(x: 0, y: 25, width: 720, height: 875)
        let windows = MockAccessibilityWindows(frontmostWindow: window)
        windows.frameResult = .success(currentFrame)
        let calculator = MockWindowPositionCalculator(result: WindowCalculationResult(frame: currentFrame, resolvedAction: .leftHalf))
        let history = MockWindowHistoryRecorder()
        let feedback = MockFailureFeedback()
        let service = makeService(windows: windows, calculator: calculator, history: history, feedback: feedback)

        let result = service.perform(action: .leftHalf)

        XCTAssertEqual(result, .failure(.targetFrameUnchanged))
        XCTAssertEqual(feedback.failureCount, 1)
        XCTAssertEqual(windows.setFrameCallCount, 0)
        XCTAssertEqual(windows.capturedSetFrames, [])
        XCTAssertEqual(history.records.count, 0)
    }

    func testPerformFailsWhenSetFrameFailsAndDoesNotRecordHistory() {
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let originalFrame = CGRect(x: 100, y: 100, width: 500, height: 400)
        let targetFrame = CGRect(x: 0, y: 25, width: 720, height: 875)
        let windows = MockAccessibilityWindows(frontmostWindow: window)
        windows.frameResult = .success(originalFrame)
        windows.setFrameResult = .failure(AccessibilityWindowError.frameWriteFailed(attribute: "kAXSizeAttribute"))
        let calculator = MockWindowPositionCalculator(result: WindowCalculationResult(frame: targetFrame, resolvedAction: .leftHalf))
        let history = MockWindowHistoryRecorder()
        let feedback = MockFailureFeedback()
        let service = makeService(windows: windows, calculator: calculator, history: history, feedback: feedback)

        let result = service.perform(action: .leftHalf)

        XCTAssertEqual(result, .failure(.setFrameFailed))
        XCTAssertEqual(feedback.failureCount, 1)
        XCTAssertEqual(windows.setFrameCallCount, 1)
        XCTAssertEqual(windows.capturedSetFrames, [targetFrame])
        XCTAssertEqual(history.records.count, 0)
    }

    func testPerformFailsWhenCalculationReturnsNil() {
        let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
        let windows = MockAccessibilityWindows(frontmostWindow: window)
        windows.frameResult = .success(CGRect(x: 100, y: 100, width: 500, height: 400))
        let screens = MockScreenProvider(displayFrames: [
            DisplayFrame(
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875),
                isMain: true
            )
        ])
        let calculator = MockWindowPositionCalculator()
        calculator.calculateHandler = { _ in nil }
        let history = MockWindowHistoryRecorder()
        let feedback = MockFailureFeedback()
        let service = makeService(windows: windows, screens: screens, calculator: calculator, history: history, feedback: feedback)

        let result = service.perform(action: .leftHalf)

        XCTAssertEqual(result, .failure(.calculationFailed))
        XCTAssertEqual(feedback.failureCount, 1)
        XCTAssertEqual(windows.setFrameCallCount, 0)
        XCTAssertEqual(history.records.count, 0)
        XCTAssertEqual(calculator.capturedInputs.first?.windowFrame, CGRect(x: 100, y: 100, width: 500, height: 400))
        XCTAssertEqual(calculator.capturedInputs.first?.sourceVisibleFrame, CGRect(x: 0, y: 25, width: 1440, height: 875))
        XCTAssertEqual(calculator.capturedInputs.first?.destinationVisibleFrame, CGRect(x: 0, y: 25, width: 1440, height: 875))
    }

    func testPerformRejectsSheetAndSystemDialogBeforeCalculation() {
        let sheetWindow = AccessibilityWindow.mock(
            applicationIdentifier: "com.example.App",
            elementID: "sheet-1",
            isSheet: true,
            isSystemDialog: true
        )
        let windows = MockAccessibilityWindows(frontmostWindow: sheetWindow)
        let calculator = MockWindowPositionCalculator()
        calculator.calculateHandler = { _ in
            XCTFail("Calculation must not run for sheet/system dialog windows.")
            return nil
        }
        let feedback = MockFailureFeedback()
        let service = makeService(windows: windows, calculator: calculator, feedback: feedback)

        let result = service.perform(action: .fullscreen)

        XCTAssertEqual(result, .failure(.unsupportedWindow(.sheetOrSystemDialog)))
        XCTAssertEqual(feedback.failureCount, 1)
        XCTAssertEqual(windows.frameCallCount, 0)
        XCTAssertEqual(calculator.calculateCallCount, 0)
        XCTAssertEqual(windows.setFrameCallCount, 0)
    }

    func testPerformFailsWhenFocusedWindowIsMissing() {
        let windows = MockAccessibilityWindows()
        windows.frontmostWindowHandler = {
            throw AccessibilityWindowError.focusedWindowMissing
        }
        let calculator = MockWindowPositionCalculator()
        calculator.calculateHandler = { _ in
            XCTFail("Calculation must not run when there is no focused window.")
            return nil
        }
        let feedback = MockFailureFeedback()
        let service = makeService(windows: windows, calculator: calculator, feedback: feedback)

        let result = service.perform(action: .leftHalf)

        XCTAssertEqual(result, .failure(.focusedWindowMissing))
        XCTAssertEqual(feedback.failureCount, 1)
        XCTAssertEqual(calculator.calculateCallCount, 0)
    }

    func testPerformFailsWithoutAccessibilityPermissionAndDoesNotRequestWindow() {
        let permission = MockAccessibilityPermission(isTrusted: false)
        let windows = MockAccessibilityWindows()
        windows.frontmostWindowHandler = {
            XCTFail("Window lookup must not run without Accessibility permission.")
            throw AccessibilityWindowError.focusedWindowMissing
        }
        let feedback = MockFailureFeedback()
        let service = makeService(permission: permission, windows: windows, feedback: feedback)

        let result = service.perform(action: .leftHalf)

        XCTAssertEqual(result, .failure(.accessibilityPermissionMissing))
        XCTAssertEqual(feedback.failureCount, 1)
        XCTAssertEqual(windows.frontmostWindowCallCount, 0)
    }
}

private func makeService(
    permission: MockAccessibilityPermission = MockAccessibilityPermission(isTrusted: true),
    windows: MockAccessibilityWindows = MockAccessibilityWindows(frontmostWindow: .mock(applicationIdentifier: "com.example.App", elementID: "window-1")),
    screens: MockScreenProvider = MockScreenProvider(displayFrames: [DisplayFrame(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875), isMain: true)]),
    calculator: MockWindowPositionCalculator = MockWindowPositionCalculator(result: WindowCalculationResult(frame: CGRect(x: 0, y: 25, width: 720, height: 875), resolvedAction: .leftHalf)),
    history: MockWindowHistoryRecorder = MockWindowHistoryRecorder(),
    feedback: MockFailureFeedback = MockFailureFeedback()
) -> WindowManagementService {
    WindowManagementService(
        permission: permission,
        windows: windows,
        screens: screens,
        calculator: calculator,
        history: history,
        feedback: feedback
    )
}

private final class MockAccessibilityPermission: AccessibilityPermissionChecking {
    var trusted: Bool

    init(isTrusted: Bool) {
        trusted = isTrusted
    }

    var isTrusted: Bool {
        trusted
    }

    func requestPrompt() {}
}

private final class MockAccessibilityWindows: AccessibilityWindowControlling {
    var frontmostWindowHandler: () throws -> AccessibilityWindow
    var frontmostWindowCallCount = 0
    var frameCallCount = 0
    var setFrameCallCount = 0
    var frameResult: Result<CGRect, Error> = .success(CGRect(x: 100, y: 100, width: 500, height: 400))
    var frameResults: [Result<CGRect, Error>] = []
    var setFrameResult: Result<Void, Error> = .success(())
    var capturedSetFrames: [CGRect] = []

    init(frontmostWindow: AccessibilityWindow = .mock(applicationIdentifier: "com.example.App", elementID: "window-1")) {
        frontmostWindowHandler = { frontmostWindow }
    }

    func frontmostWindow() throws -> AccessibilityWindow {
        frontmostWindowCallCount += 1
        return try frontmostWindowHandler()
    }

    func frame(of window: AccessibilityWindow) throws -> CGRect {
        frameCallCount += 1
        if !frameResults.isEmpty {
            return try frameResults.removeFirst().get()
        }
        return try frameResult.get()
    }

    func setFrame(_ frame: CGRect, of window: AccessibilityWindow) throws {
        setFrameCallCount += 1
        capturedSetFrames.append(frame)
        try setFrameResult.get()
    }
}

private struct MockScreenProvider: ScreenProviding {
    var displayFrames: [DisplayFrame]
}

private final class MockWindowPositionCalculator: WindowPositionCalculating {
    var calculateHandler: (WindowCalculationInput) -> WindowCalculationResult?
    var calculateCallCount = 0
    var capturedInputs: [WindowCalculationInput] = []

    init(result: WindowCalculationResult? = WindowCalculationResult(frame: CGRect(x: 0, y: 25, width: 720, height: 875), resolvedAction: .leftHalf)) {
        calculateHandler = { _ in result }
    }

    func calculate(_ input: WindowCalculationInput) -> WindowCalculationResult? {
        calculateCallCount += 1
        capturedInputs.append(input)
        return calculateHandler(input)
    }
}

private final class MockWindowHistoryRecorder: WindowHistoryRecording {
    struct Record: Equatable {
        let applicationIdentifier: String
        let previousFrame: CGRect
        let targetFrame: CGRect
    }

    struct HistoryRequest: Equatable {
        let applicationIdentifier: String
        let currentFrame: CGRect
    }

    var records: [Record] = []
    var undoItem: WindowHistoryItem?
    var redoItem: WindowHistoryItem?
    var undoRequests: [HistoryRequest] = []
    var redoRequests: [HistoryRequest] = []

    func recordSuccessfulMove(applicationIdentifier: String, previousFrame: CGRect, targetFrame: CGRect) {
        records.append(Record(applicationIdentifier: applicationIdentifier, previousFrame: previousFrame, targetFrame: targetFrame))
    }

    func undo(applicationIdentifier: String, currentFrame: CGRect) -> WindowHistoryItem? {
        undoRequests.append(HistoryRequest(applicationIdentifier: applicationIdentifier, currentFrame: currentFrame))
        return undoItem
    }

    func redo(applicationIdentifier: String, currentFrame: CGRect) -> WindowHistoryItem? {
        redoRequests.append(HistoryRequest(applicationIdentifier: applicationIdentifier, currentFrame: currentFrame))
        return redoItem
    }
}

private final class MockFailureFeedback: FailureFeedback {
    var failureCount = 0

    func signalFailure() {
        failureCount += 1
    }
}
