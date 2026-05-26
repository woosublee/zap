import AppKit
import SwiftUI

@MainActor
enum AboutWindowPresenter {
    private static var window: NSWindow?

    static func open() {
        if window == nil {
            window = makeWindow(info: .current, appName: AboutPresentation.currentAppName)
        }

        guard let window else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    static func makeWindow(info: AboutInfo, appName: String = AboutPresentation.currentAppName) -> NSWindow {
        let presentation = AboutPresentation(appName: appName, info: info)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = AboutPresentation.aboutMenuLabel(appName: appName)
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentViewController = NSHostingController(rootView: AboutView(presentation: presentation))
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
