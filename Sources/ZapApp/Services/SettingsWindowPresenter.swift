import AppKit
import SwiftUI

@MainActor
enum SettingsWindowPresenter {
    private static var window: NSWindow?

    static func open(
        model: ZapAppModel,
        updateService: UpdateService,
        showMenuBarIcon: Binding<Bool>,
        initialMode: SettingsMode = .automatic
    ) {
        if window == nil {
            window = makeWindow(model: model, updateService: updateService, showMenuBarIcon: showMenuBarIcon, initialMode: initialMode)
        }

        guard let window else { return }
        window.contentViewController = NSHostingController(
            rootView: SettingsView(model: model, updateService: updateService, showMenuBarIcon: showMenuBarIcon, initialMode: initialMode)
        )
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private static func makeWindow(model: ZapAppModel, updateService: UpdateService, showMenuBarIcon: Binding<Bool>, initialMode: SettingsMode = .automatic) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AboutPresentation.currentAppName) Settings"
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentViewController = NSHostingController(
            rootView: SettingsView(model: model, updateService: updateService, showMenuBarIcon: showMenuBarIcon, initialMode: initialMode)
        )
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
