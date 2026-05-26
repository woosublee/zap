import AppKit
import SwiftUI

@MainActor
enum SettingsWindowPresenter {
    private static var window: NSWindow?

    static func open(model: SnapAppModel, showMenuBarIcon: Binding<Bool>) {
        if window == nil {
            window = makeWindow(model: model, showMenuBarIcon: showMenuBarIcon)
        }

        guard let window else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    static func open(model: SnapAppModel) {
        open(model: model, showMenuBarIcon: Binding(
            get: { UserDefaults.standard.object(forKey: "show_menu_bar_icon") as? Bool ?? true },
            set: { newValue in
                UserDefaults.standard.set(newValue, forKey: "show_menu_bar_icon")
                AppActivationPolicy.apply(showMenuBarIcon: newValue)
            }
        ))
    }

    private static func makeWindow(model: SnapAppModel, showMenuBarIcon: Binding<Bool>) -> NSWindow {
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
            rootView: SettingsView(model: model, showMenuBarIcon: showMenuBarIcon)
        )
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
