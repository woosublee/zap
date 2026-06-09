import AppKit
import CoreGraphics
import ZapCore

enum UnsupportedWindowReason: Equatable {
    case sheetOrSystemDialog
}

enum WindowManagementError: Equatable {
    case accessibilityPermissionMissing
    case focusedWindowMissing
    case unsupportedWindow(UnsupportedWindowReason)
    case frameReadFailed
    case calculationFailed
    case targetFrameUnchanged
    case setFrameFailed
}

enum WindowManagementResult: Equatable {
    case success(action: WindowAction, frame: CGRect)
    case failure(WindowManagementError)
}

protocol ScreenProviding {
    var displayFrames: [DisplayFrame] { get }
}

protocol WindowPositionCalculating {
    func calculate(_ input: WindowCalculationInput) -> WindowCalculationResult?
}

protocol WindowHistoryRecording: AnyObject {
    func recordSuccessfulMove(applicationIdentifier: String, previousFrame: CGRect, targetFrame: CGRect)
    func undo(applicationIdentifier: String, currentFrame: CGRect) -> WindowHistoryItem?
    func redo(applicationIdentifier: String, currentFrame: CGRect) -> WindowHistoryItem?
}

protocol FailureFeedback {
    func signalFailure()
}

struct WindowManagementService {
    private let permission: AccessibilityPermissionChecking
    private let windows: AccessibilityWindowControlling
    private let screens: ScreenProviding
    private let calculator: WindowPositionCalculating
    private let history: WindowHistoryRecording
    private let feedback: FailureFeedback
    private let screenDetector: ScreenDetector

    init(
        permission: AccessibilityPermissionChecking = AccessibilityPermissionService(),
        windows: AccessibilityWindowControlling = AccessibilityWindowService(),
        screens: ScreenProviding = NSScreenProvider(),
        calculator: WindowPositionCalculating = ZapCoreWindowPositionCalculatorAdapter(),
        history: WindowHistoryRecording,
        feedback: FailureFeedback = SystemFailureFeedback(),
        screenDetector: ScreenDetector = ScreenDetector()
    ) {
        self.permission = permission
        self.windows = windows
        self.screens = screens
        self.calculator = calculator
        self.history = history
        self.feedback = feedback
        self.screenDetector = screenDetector
    }

    func perform(action: WindowAction) -> WindowManagementResult {
        guard permission.isTrusted else {
            return fail(.accessibilityPermissionMissing)
        }

        let window: AccessibilityWindow
        do {
            window = try windows.frontmostWindow()
        } catch AccessibilityWindowError.focusedWindowMissing {
            return fail(.focusedWindowMissing)
        } catch {
            return fail(.focusedWindowMissing)
        }

        guard !window.isSheet && !window.isSystemDialog else {
            return fail(.unsupportedWindow(.sheetOrSystemDialog))
        }

        let currentFrame: CGRect
        do {
            currentFrame = try windows.frame(of: window)
        } catch {
            return fail(.frameReadFailed)
        }

        if action == .undo || action == .redo {
            return performHistoryAction(action, for: window, currentFrame: currentFrame)
        }

        let displayContext: DisplayContext
        do {
            displayContext = try screenDetector.displayContext(
                for: currentFrame,
                action: action,
                displays: screens.displayFrames
            )
        } catch {
            return fail(.calculationFailed)
        }

        let input = WindowCalculationInput(
            windowFrame: currentFrame,
            sourceVisibleFrame: displayContext.sourceVisibleFrame,
            destinationVisibleFrame: displayContext.destinationVisibleFrame,
            action: action
        )

        guard let result = calculator.calculate(input) else {
            return fail(.calculationFailed)
        }

        guard !result.frame.equalTo(currentFrame) else {
            return fail(.targetFrameUnchanged)
        }

        do {
            try windows.setFrame(result.frame, of: window)
        } catch {
            return fail(.setFrameFailed)
        }

        let actualFrame: CGRect
        do {
            actualFrame = try windows.frame(of: window)
        } catch {
            return fail(.frameReadFailed)
        }

        history.recordSuccessfulMove(
            applicationIdentifier: window.applicationIdentifier,
            previousFrame: currentFrame,
            targetFrame: actualFrame
        )
        return .success(action: result.resolvedAction, frame: actualFrame)
    }

    private func performHistoryAction(
        _ action: WindowAction,
        for window: AccessibilityWindow,
        currentFrame: CGRect
    ) -> WindowManagementResult {
        let item: WindowHistoryItem?
        switch action {
        case .undo:
            item = history.undo(applicationIdentifier: window.applicationIdentifier, currentFrame: currentFrame)
        case .redo:
            item = history.redo(applicationIdentifier: window.applicationIdentifier, currentFrame: currentFrame)
        default:
            item = nil
        }

        guard let item else {
            return fail(.calculationFailed)
        }

        do {
            try windows.setFrame(item.windowFrame, of: window)
        } catch {
            return fail(.setFrameFailed)
        }

        let actualFrame: CGRect
        do {
            actualFrame = try windows.frame(of: window)
        } catch {
            return fail(.frameReadFailed)
        }

        return .success(action: action, frame: actualFrame)
    }

    private func fail(_ error: WindowManagementError) -> WindowManagementResult {
        feedback.signalFailure()
        return .failure(error)
    }
}

struct NSScreenProvider: ScreenProviding {
    var displayFrames: [DisplayFrame] {
        NSScreen.screens.map { screen in
            DisplayFrame(
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                isMain: screen == NSScreen.main
            )
        }
    }
}

struct ZapCoreWindowPositionCalculatorAdapter: WindowPositionCalculating {
    private let calculator: WindowPositionCalculator

    init(calculator: WindowPositionCalculator = WindowPositionCalculator()) {
        self.calculator = calculator
    }

    func calculate(_ input: WindowCalculationInput) -> WindowCalculationResult? {
        calculator.calculate(input)
    }
}

final class DefaultWindowHistoryRecorder: WindowHistoryRecording {
    private var history = WindowHistory()

    func recordSuccessfulMove(applicationIdentifier: String, previousFrame: CGRect, targetFrame: CGRect) {
        history.record(applicationIdentifier: applicationIdentifier, frame: previousFrame)
    }

    func undo(applicationIdentifier: String, currentFrame: CGRect) -> WindowHistoryItem? {
        history.undo(applicationIdentifier: applicationIdentifier, currentFrame: currentFrame)
    }

    func redo(applicationIdentifier: String, currentFrame: CGRect) -> WindowHistoryItem? {
        history.redo(applicationIdentifier: applicationIdentifier, currentFrame: currentFrame)
    }
}

struct SystemFailureFeedback: FailureFeedback {
    func signalFailure() {
        NSSound.beep()
    }
}
