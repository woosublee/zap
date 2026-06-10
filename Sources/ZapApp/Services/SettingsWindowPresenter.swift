import AppKit
import SwiftUI

@MainActor
enum SettingsWindowPresenter {
    private static var window: NSWindow?
    private static var navigationState = SettingsNavigationState()

    static func open(
        model: ZapAppModel,
        updateService: UpdateService,
        showMenuBarIcon: Binding<Bool>,
        initialMode: SettingsMode? = nil
    ) {
        if window == nil {
            navigationState = SettingsNavigationState(selectedMode: initialMode ?? .automatic)
            window = makeWindow(model: model, updateService: updateService, showMenuBarIcon: showMenuBarIcon)
        } else if let initialMode {
            navigationState.selectedMode = initialMode
        }

        guard let window else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private static func makeWindow(model: ZapAppModel, updateService: UpdateService, showMenuBarIcon: Binding<Bool>) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 640),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AboutPresentation.currentAppName) Settings"
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentViewController = NSHostingController(
            rootView: SettingsView(
                model: model,
                updateService: updateService,
                showMenuBarIcon: showMenuBarIcon,
                navigationState: navigationState
            )
        )
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
