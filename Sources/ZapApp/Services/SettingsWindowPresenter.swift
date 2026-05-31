import AppKit
import SwiftUI

@MainActor
enum SettingsWindowPresenter {
    private static var window: NSWindow?

    static func open(model: ZapAppModel, updateService: UpdateService, showMenuBarIcon: Binding<Bool>) {
        if window == nil {
            window = makeWindow(model: model, updateService: updateService, showMenuBarIcon: showMenuBarIcon)
        }

        guard let window else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private static func makeWindow(model: ZapAppModel, updateService: UpdateService, showMenuBarIcon: Binding<Bool>) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AboutPresentation.currentAppName) Settings"
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentViewController = NSHostingController(
            rootView: SettingsView(model: model, updateService: updateService, showMenuBarIcon: showMenuBarIcon)
        )
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
