import AppKit
import SwiftUI

@main
struct SnapApp: App {
    @NSApplicationDelegateAdaptor(SnapApplicationDelegate.self) private var appDelegate
    @StateObject private var model = SnapAppModel()
    @AppStorage("show_menu_bar_icon") private var showMenuBarIcon = true

    init() {
        let savedValue = UserDefaults.standard.object(forKey: "show_menu_bar_icon") as? Bool ?? true
        AppActivationPolicy.apply(showMenuBarIcon: savedValue)
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarView(
                model: model,
                openSettings: { openSettings() },
                quit: { NSApp.terminate(nil) }
            )
            .onAppear {
                appDelegate.openSettings = { openSettings() }
            }
        } label: {
            menuBarIcon
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit Snap") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }

    @ViewBuilder
    private var menuBarIcon: some View {
        if let image = NSImage(named: "SnapMenuBarIcon")?.templateCopy(pointSize: NSSize(width: 18, height: 18)) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .accessibilityLabel("Snap")
        } else {
            Image(systemName: "bolt.fill")
                .accessibilityLabel("Snap")
        }
    }

    private func openSettings() {
        appDelegate.openSettings = { openSettings() }
        SettingsWindowPresenter.open(model: model, showMenuBarIcon: $showMenuBarIcon)
    }
}

private extension NSImage {
    func templateCopy(pointSize: NSSize) -> NSImage {
        let copiedImage = copy() as? NSImage ?? self
        copiedImage.size = pointSize
        copiedImage.isTemplate = true
        return copiedImage
    }
}
