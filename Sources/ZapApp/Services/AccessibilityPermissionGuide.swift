import AppKit
import PermissionFlow

@MainActor
protocol AccessibilityPermissionGuiding {
    func start(sourceFrame: CGRect?)
}

/// The only PermissionFlow touchpoint: opens the Accessibility pane and shows
/// the drag-to-authorize panel next to System Settings.
@MainActor
final class AccessibilityPermissionGuide: AccessibilityPermissionGuiding {
    private let permission: AccessibilityPermissionChecking
    private let authorizeOverride: ((CGRect?) -> Void)?
    // Lazy so constructing Zap's models does not start PermissionFlow's frontmost-app observers.
    private lazy var controller = PermissionFlow.makeController(
        configuration: .init(
            requiredAppURLs: [Bundle.main.bundleURL],
            promptForAccessibilityTrust: false
        )
    )

    init(
        permission: AccessibilityPermissionChecking = AccessibilityPermissionService(),
        authorize: ((CGRect?) -> Void)? = nil
    ) {
        self.permission = permission
        self.authorizeOverride = authorize
    }

    func start(sourceFrame: CGRect?) {
        guard !permission.isTrusted else { return }

        if let authorizeOverride {
            authorizeOverride(sourceFrame)
            return
        }

        controller.authorize(
            pane: .accessibility,
            suggestedAppURLs: [Bundle.main.bundleURL],
            sourceFrameInScreen: sourceFrame
        )
    }
}
