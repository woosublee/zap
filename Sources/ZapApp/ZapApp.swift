import AppKit
import SwiftUI

@main
struct ZapApp: App {
    @NSApplicationDelegateAdaptor(ZapApplicationDelegate.self) private var appDelegate
    @StateObject private var model: ZapAppModel
    @StateObject private var updateService: UpdateService
    @AppStorage("show_menu_bar_icon") private var showMenuBarIcon = true

    init() {
        let savedValue = UserDefaults.standard.object(forKey: "show_menu_bar_icon") as? Bool ?? true
        AppActivationPolicy.apply(showMenuBarIcon: savedValue)
        if let icon = BuildFlavorIcons.appIcon(base: NSApplication.shared.applicationIconImage, flavor: AppBuildFlavor.current) {
            NSApplication.shared.applicationIconImage = icon
        }

        let updateService = UpdateService()
        _updateService = StateObject(wrappedValue: updateService)
        _model = StateObject(wrappedValue: ZapAppModel(updateService: updateService))
        Self.startUpdateServiceOnAppLaunch(updateService)
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarView(
                model: model,
                updateService: updateService,
                openSettings: { openSettings() },
                quit: { NSApp.terminate(nil) }
            )
        } label: {
            menuBarIcon
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)

                Button("Check for Updates...") {
                    updateService.checkForUpdates()
                }
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit \(AboutPresentation.currentAppName)") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }

    @ViewBuilder
    private var menuBarIcon: some View {
        if let base = NSImage(named: "ZapMenuBarIcon") {
            let image = BuildFlavorIcons.menuBarIcon(base: base, flavor: AppBuildFlavor.current)
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .accessibilityLabel(AboutPresentation.currentAppName)
        } else {
            Image(systemName: "bolt.fill")
                .accessibilityLabel(AboutPresentation.currentAppName)
        }
    }

    private func openSettings(initialMode: SettingsMode? = nil) {
        SettingsWindowPresenter.open(
            model: model,
            updateService: updateService,
            showMenuBarIcon: $showMenuBarIcon,
            initialMode: initialMode
        )
    }


    static func startUpdateServiceOnAppLaunch(_ updateService: UpdateService) {
        Task { @MainActor in
            updateService.start()
        }
    }
}
