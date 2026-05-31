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
                openSettings: { openSettings() },
                openAbout: { openAbout() },
                quit: { NSApp.terminate(nil) }
            )
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
        if let image = NSImage(named: "ZapMenuBarIcon")?.templateCopy(pointSize: NSSize(width: 18, height: 18)) {
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

    private func openSettings() {
        SettingsWindowPresenter.open(
            model: model,
            updateService: updateService,
            showMenuBarIcon: $showMenuBarIcon
        )
    }

    private func openAbout() {
        AboutWindowPresenter.open()
    }

    static func startUpdateServiceOnAppLaunch(_ updateService: UpdateService) {
        Task { @MainActor in
            updateService.start()
        }
    }
}

private extension NSImage {
    func templateCopy(pointSize: NSSize) -> NSImage {
        guard let copiedImage = copy() as? NSImage else {
            return self
        }
        copiedImage.size = pointSize
        copiedImage.isTemplate = true
        return copiedImage
    }
}
