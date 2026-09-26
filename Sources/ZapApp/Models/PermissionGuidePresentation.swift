import AppKit

/// Limits the shortcut-triggered permission guide to one start per app session.
struct PermissionGuideThrottle {
    private var hasStarted = false

    mutating func shouldStart() -> Bool {
        guard !hasStarted else { return false }
        hasStarted = true
        return true
    }
}

/// System Settings renamed the Accessibility privacy page in macOS 27.
enum AccessibilityPaneName {
    static func title(for version: OperatingSystemVersion) -> String {
        version.majorVersion >= 27 ? "Device Control and Data Access" : "Accessibility"
    }

    static var current: String {
        title(for: ProcessInfo.processInfo.operatingSystemVersion)
    }
}

/// Screen-space launch point for the guide panel's fly-in animation.
enum PermissionGuideSourceFrame {
    private static let side: CGFloat = 32

    static func around(_ point: CGPoint) -> CGRect {
        CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
    }

    @MainActor
    static var atMouse: CGRect {
        around(NSEvent.mouseLocation)
    }
}
