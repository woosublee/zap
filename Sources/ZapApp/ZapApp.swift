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
                openAbout: { AboutWindowPresenter.open() },
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

                if AppDistribution.current.supportsInAppUpdates {
                    Button("Check for Updates...") {
                        updateService.checkForUpdates()
                    }
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
        Image(nsImage: BuildFlavorIcons.menuBarIcon(flavor: AppBuildFlavor.current))
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .accessibilityLabel(AboutPresentation.currentAppName)
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
