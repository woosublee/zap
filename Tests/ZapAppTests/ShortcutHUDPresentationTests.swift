import AppKit
import XCTest
@testable import ZapApp
@testable import ZapCore

final class ShortcutHUDPresentationTests: XCTestCase {
    func testAutomaticDockApplicationUsesLocalizedNameAndItemMetadata() {
        let item = DockItem(
            name: "Terminal fallback",
            url: URL(fileURLWithPath: "/Applications/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal"
        )

        let application = ShortcutHUDApplication(
            item: item,
            localizedDisplayName: { _ in "Localized Terminal" }
        )
        let payload = ShortcutHUDPayload.appActivated(application: application)

        XCTAssertEqual(application.name, "Localized Terminal")
        XCTAssertEqual(payload.appName, "Localized Terminal")
        XCTAssertEqual(payload.applicationURL, item.url)
        XCTAssertEqual(payload.bundleIdentifier, item.bundleIdentifier)
    }

    func testAutomaticDockApplicationFallsBackThroughItemMetadata() {
        let named = DockItem(
            name: "Dock Name",
            url: URL(fileURLWithPath: "/Applications/Named.app"),
            bundleIdentifier: "com.example.Named"
        )
        let bundleOnly = DockItem(
            name: "",
            url: URL(fileURLWithPath: "/Applications/Bundle.app"),
            bundleIdentifier: "com.example.Bundle"
        )
        let fileOnly = DockItem(
            name: " ",
            url: URL(fileURLWithPath: "/Applications/File Only.app"),
            bundleIdentifier: nil
        )

        XCTAssertEqual(
            ShortcutHUDApplication(item: named, localizedDisplayName: { _ in nil }).name,
            "Dock Name"
        )
        XCTAssertEqual(
            ShortcutHUDApplication(item: bundleOnly, localizedDisplayName: { _ in nil }).name,
            "com.example.Bundle"
        )
        XCTAssertEqual(
            ShortcutHUDApplication(item: fileOnly, localizedDisplayName: { _ in nil }).name,
            "File Only"
        )
    }

    func testFinderApplicationUsesCanonicalMetadataAndActivationPresentation() {
        let application = ShortcutHUDApplication.finder
        let payload = ShortcutHUDPayload.appActivated(application: application)
        let presentation = ShortcutHUDPresentation(
            payload: payload,
            reduceMotion: false,
            reduceTransparency: false
        )

        XCTAssertEqual(application.name, "Finder")
        XCTAssertEqual(application.bundleIdentifier, "com.apple.finder")
        XCTAssertNil(application.applicationURL)
        XCTAssertEqual(payload.appName, "Finder")
        XCTAssertEqual(presentation.badge, .none)
        XCTAssertEqual(presentation.announcement, "Finder activated")
    }

    func testPresentationMapsActionsToBadgeAndEnglishAnnouncement() {
        let activated = ShortcutHUDPayload(
            action: .appActivated,
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            applicationURL: nil
        )
        let disabled = ShortcutHUDPayload(
            action: .appHotKeysDisabled,
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            applicationURL: nil
        )
        let enabled = ShortcutHUDPayload(
            action: .appHotKeysEnabled,
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            applicationURL: nil
        )

        XCTAssertEqual(
            ShortcutHUDPresentation(payload: activated, reduceMotion: false, reduceTransparency: false),
            ShortcutHUDPresentation(
                badge: .none,
                announcement: "Safari activated",
                usesScaleAnimation: true,
                usesOpaqueBackground: false
            )
        )
        XCTAssertEqual(
            ShortcutHUDPresentation(payload: disabled, reduceMotion: false, reduceTransparency: false).badge,
            .disabled
        )
        XCTAssertEqual(
            ShortcutHUDPresentation(payload: disabled, reduceMotion: false, reduceTransparency: false).announcement,
            "Zap shortcuts disabled in Safari"
        )
        XCTAssertEqual(
            ShortcutHUDPresentation(payload: enabled, reduceMotion: false, reduceTransparency: false).badge,
            .enabled
        )
        XCTAssertEqual(
            ShortcutHUDPresentation(payload: enabled, reduceMotion: false, reduceTransparency: false).announcement,
            "Zap shortcuts enabled in Safari"
        )
    }

    func testAccessibilityPreferencesChangeOnlyTheirOwnPresentationPolicy() {
        let payload = ShortcutHUDPayload(
            action: .appActivated,
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            applicationURL: nil
        )
        let cases = [
            (reduceMotion: false, reduceTransparency: false, scale: true, opaque: false),
            (reduceMotion: true, reduceTransparency: false, scale: false, opaque: false),
            (reduceMotion: false, reduceTransparency: true, scale: true, opaque: true),
            (reduceMotion: true, reduceTransparency: true, scale: false, opaque: true)
        ]

        for value in cases {
            let presentation = ShortcutHUDPresentation(
                payload: payload,
                reduceMotion: value.reduceMotion,
                reduceTransparency: value.reduceTransparency
            )

            XCTAssertEqual(presentation.usesScaleAnimation, value.scale)
            XCTAssertEqual(presentation.usesOpaqueBackground, value.opaque)
        }
    }

    func testLayoutCentersCardOnDisplayAndLeavesShadowInset() {
        let display = DisplayFrame(
            frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055),
            isMain: false
        )

        let panelFrame = ShortcutHUDLayout.panelFrame(on: display)

        XCTAssertEqual(ShortcutHUDLayout.cardSize, CGSize(width: 132, height: 132))
        XCTAssertEqual(ShortcutHUDLayout.iconSize, CGSize(width: 76, height: 76))
        XCTAssertEqual(ShortcutHUDLayout.glassBorderWidth, 1.5)
        XCTAssertEqual(ShortcutHUDLayout.innerHighlightInset, 4)
        XCTAssertEqual(ShortcutHUDLayout.innerHighlightCornerRadius, 28)
        XCTAssertGreaterThan(panelFrame.width, ShortcutHUDLayout.cardSize.width)
        XCTAssertGreaterThan(panelFrame.height, ShortcutHUDLayout.cardSize.height)
        XCTAssertEqual(panelFrame.midX, display.frame.midX, accuracy: 0.001)
        XCTAssertEqual(panelFrame.midY, display.frame.midY, accuracy: 0.001)
    }
}
