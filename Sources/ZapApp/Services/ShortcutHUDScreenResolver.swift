import AppKit
import ZapCore

@MainActor
protocol ShortcutHUDScreenResolving {
    func resolveScreenBeforeAction() -> DisplayFrame?
}

@MainActor
struct ShortcutHUDScreenResolver: ShortcutHUDScreenResolving {
    private let permission: AccessibilityPermissionChecking
    private let windows: AccessibilityWindowControlling
    private let screens: ScreenProviding
    private let screenDetector: ScreenDetector
    private let mouseLocation: () -> CGPoint

    init(
        permission: AccessibilityPermissionChecking = AccessibilityPermissionService(),
        windows: AccessibilityWindowControlling = AccessibilityWindowService(),
        screens: ScreenProviding = NSScreenProvider(),
        screenDetector: ScreenDetector = ScreenDetector(),
        mouseLocation: @escaping () -> CGPoint = { NSEvent.mouseLocation }
    ) {
        self.permission = permission
        self.windows = windows
        self.screens = screens
        self.screenDetector = screenDetector
        self.mouseLocation = mouseLocation
    }

    func resolveScreenBeforeAction() -> DisplayFrame? {
        let displays = screens.displayFrames
        guard !displays.isEmpty else { return nil }

        if permission.isTrusted,
           let display = focusedWindowDisplay(in: displays) {
            return display
        }

        let point = mouseLocation()
        if let mouseDisplay = displays.first(where: { $0.frame.contains(point) }) {
            return mouseDisplay
        }
        return displays.first(where: \.isMain) ?? displays.first
    }

    private func focusedWindowDisplay(
        in displays: [DisplayFrame]
    ) -> DisplayFrame? {
        do {
            let window = try windows.frontmostWindow()
            let frame = try windows.frame(of: window)
            return try screenDetector.sourceDisplay(
                for: frame,
                displays: displays
            )
        } catch {
            return nil
        }
    }
}
