import CoreGraphics
import Foundation
import ZapCore

enum ShortcutHUDAction: Equatable {
    case appActivated
    case appHotKeysDisabled
    case appHotKeysEnabled
}

struct ShortcutHUDApplication: Equatable {
    let name: String
    let bundleIdentifier: String?
    let applicationURL: URL?

    init(
        name: String,
        bundleIdentifier: String?,
        applicationURL: URL?
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.applicationURL = applicationURL
    }

    init(
        item: DockItem,
        localizedDisplayName: (URL) -> String?
    ) {
        let candidates: [String?] = [
            localizedDisplayName(item.url),
            item.name,
            item.bundleIdentifier,
            item.url.deletingPathExtension().lastPathComponent
        ]
        name = candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "Application"
        bundleIdentifier = item.bundleIdentifier
        applicationURL = item.url
    }

    static let finder = ShortcutHUDApplication(
        name: "Finder",
        bundleIdentifier: "com.apple.finder",
        applicationURL: nil
    )
}

struct ShortcutHUDPayload: Equatable {
    let action: ShortcutHUDAction
    let appName: String
    let bundleIdentifier: String?
    let applicationURL: URL?

    static func appActivated(
        application: ShortcutHUDApplication
    ) -> ShortcutHUDPayload {
        ShortcutHUDPayload(
            action: .appActivated,
            appName: application.name,
            bundleIdentifier: application.bundleIdentifier,
            applicationURL: application.applicationURL
        )
    }

    static func appHotKeys(
        action: ShortcutHUDAction,
        application: ActiveApplication
    ) -> ShortcutHUDPayload {
        let trimmedName = application.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return ShortcutHUDPayload(
            action: action,
            appName: trimmedName.isEmpty ? application.bundleIdentifier : trimmedName,
            bundleIdentifier: application.bundleIdentifier,
            applicationURL: nil
        )
    }
}

enum ShortcutHUDBadge: Equatable {
    case none
    case disabled
    case enabled
}

struct ShortcutHUDPresentation: Equatable {
    let badge: ShortcutHUDBadge
    let announcement: String
    let usesScaleAnimation: Bool
    let usesOpaqueBackground: Bool

    init(
        badge: ShortcutHUDBadge,
        announcement: String,
        usesScaleAnimation: Bool,
        usesOpaqueBackground: Bool
    ) {
        self.badge = badge
        self.announcement = announcement
        self.usesScaleAnimation = usesScaleAnimation
        self.usesOpaqueBackground = usesOpaqueBackground
    }

    init(
        payload: ShortcutHUDPayload,
        reduceMotion: Bool,
        reduceTransparency: Bool
    ) {
        switch payload.action {
        case .appActivated:
            badge = .none
            announcement = "\(payload.appName) activated"
        case .appHotKeysDisabled:
            badge = .disabled
            announcement = "Zap shortcuts disabled in \(payload.appName)"
        case .appHotKeysEnabled:
            badge = .enabled
            announcement = "Zap shortcuts enabled in \(payload.appName)"
        }
        usesScaleAnimation = !reduceMotion
        usesOpaqueBackground = reduceTransparency
    }
}

enum ShortcutHUDLayout {
    static let cardSize = CGSize(width: 132, height: 132)
    static let iconSize = CGSize(width: 76, height: 76)
    static let cornerRadius: CGFloat = 32
    static let glassBorderWidth: CGFloat = 1.5
    static let innerHighlightInset: CGFloat = 4
    static let innerHighlightCornerRadius: CGFloat = 28
    static let motionInset: CGFloat = 20

    static var panelSize: CGSize {
        CGSize(
            width: cardSize.width + motionInset * 2,
            height: cardSize.height + motionInset * 2
        )
    }

    static func panelFrame(on display: DisplayFrame) -> CGRect {
        CGRect(
            x: display.frame.midX - panelSize.width / 2,
            y: display.frame.midY - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
    }
}

@MainActor
protocol ShortcutHUDPresenting: AnyObject {
    func present(_ payload: ShortcutHUDPayload, on display: DisplayFrame?)
}

@MainActor
final class NoOpShortcutHUDPresenter: ShortcutHUDPresenting {
    func present(_ payload: ShortcutHUDPayload, on display: DisplayFrame?) {}
}
