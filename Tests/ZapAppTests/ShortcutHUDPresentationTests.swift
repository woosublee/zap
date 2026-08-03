import AppKit
import XCTest
@testable import ZapApp
@testable import ZapCore

final class ShortcutHUDPresentationTests: XCTestCase {
    func testAutomaticDockPayloadUsesLocalizedNameBeforeDockName() {
        let item = DockItem(
            name: "Terminal fallback",
            url: URL(fileURLWithPath: "/Applications/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal"
        )

        let payload = ShortcutHUDPayload.appActivated(
            item: item,
            localizedDisplayName: { _ in "Localized Terminal" }
        )

        XCTAssertEqual(payload.appName, "Localized Terminal")
        XCTAssertEqual(payload.applicationURL, item.url)
        XCTAssertEqual(payload.bundleIdentifier, item.bundleIdentifier)
    }

    func testAutomaticDockPayloadFallsBackToDockNameThenBundleIdentifier() {
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

        XCTAssertEqual(
            ShortcutHUDPayload.appActivated(item: named, localizedDisplayName: { _ in nil }).appName,
            "Dock Name"
        )
        XCTAssertEqual(
            ShortcutHUDPayload.appActivated(item: bundleOnly, localizedDisplayName: { _ in nil }).appName,
            "com.example.Bundle"
        )
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

    func testAccessibilityPreferencesChangeOnlyAnimationAndBackgroundPolicy() {
        let payload = ShortcutHUDPayload(
            action: .appActivated,
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            applicationURL: nil
        )
        let presentation = ShortcutHUDPresentation(
            payload: payload,
            reduceMotion: true,
            reduceTransparency: true
        )

        XCTAssertFalse(presentation.usesScaleAnimation)
        XCTAssertTrue(presentation.usesOpaqueBackground)
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
        XCTAssertGreaterThan(panelFrame.width, ShortcutHUDLayout.cardSize.width)
        XCTAssertGreaterThan(panelFrame.height, ShortcutHUDLayout.cardSize.height)
        XCTAssertEqual(panelFrame.midX, display.frame.midX, accuracy: 0.001)
        XCTAssertEqual(panelFrame.midY, display.frame.midY, accuracy: 0.001)
    }
}
