import SwiftUI
import ZapCore

struct MenuBarView: View {
    @ObservedObject var model: ZapAppModel
    @ObservedObject var updateService: UpdateService
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        hotKeyControls

        Divider()

        quickLaunchMenu
        windowControlMenu

        Divider()

        Button("Refresh Dock Apps") {
            model.refreshDockItems()
        }
        Button("Check for Updates...") {
            updateService.checkForUpdates()
        }

        Divider()

        Button("Settings...") {
            openSettings()
        }
        Button("Quit \(AboutPresentation.currentAppName)") {
            quit()
        }
    }

    @ViewBuilder
    private var hotKeyControls: some View {
        if model.areHotKeysPaused {
            Button("Resume Shortcuts") {
                model.resumeHotKeys()
            }
        } else {
            Menu("Pause Shortcuts") {
                Button("For 10 Minutes") {
                    model.pauseHotKeys(for: 10 * 60)
                }
                Button("For 30 Minutes") {
                    model.pauseHotKeys(for: 30 * 60)
                }
                Button("For 1 Hour") {
                    model.pauseHotKeys(for: 60 * 60)
                }
                Button("For 2 Hours") {
                    model.pauseHotKeys(for: 2 * 60 * 60)
                }
                Button("For 4 Hours") {
                    model.pauseHotKeys(for: 4 * 60 * 60)
                }

                Divider()

                Button("Until Resumed") {
                    model.pauseHotKeysIndefinitely()
                }
            }
        }

        if let application = model.activeApplication {
            Button("\(model.isActiveApplicationDisabled ? "Enable" : "Disable") Shortcuts in \(application.name)") {
                model.toggleHotKeysForActiveApplication()
            }
        }
    }

    private var quickLaunchMenu: some View {
        Menu("Quick Launch") {
            if model.isFinderShortcutEnabled {
                Button(menuLabel("Finder", shortcut: model.finderShortcutTitle)) {
                    model.activateFinder()
                }

                if hasQuickLaunchItemsAfterFinder {
                    Divider()
                }
            }

            ForEach(model.activeManualShortcuts) { shortcut in
                Button(menuLabel(shortcut.name, shortcut: shortcut.shortcutTitle)) {
                    model.activateManualShortcut(id: shortcut.id)
                }
            }

            if !model.activeManualShortcuts.isEmpty && hasDockItems {
                Divider()
            }

            ForEach(NumberKey.allCases) { key in
                if let item = model.dockItem(for: key) {
                    Button(menuLabel(item.name, shortcut: model.shortcutTitle(for: key))) {
                        model.activateDockItem(for: key)
                    }
                }
            }
        }
    }

    private var windowControlMenu: some View {
        Menu("Window Control") {
            ForEach(WindowActionCategory.allCases, id: \.self) { category in
                windowShortcutButtons(for: category)

                if category != WindowActionCategory.allCases.last {
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func windowShortcutButtons(for category: WindowActionCategory) -> some View {
        ForEach(windowShortcuts(for: category)) { shortcut in
            Button(menuLabel(
                shortcut.action.displayName,
                shortcut: WindowShortcutDisplay.shortcutTitle(for: shortcut)
            )) {
                _ = model.windowManagementModel.perform(action: shortcut.action)
            }
        }
    }

    private var hasQuickLaunchItemsAfterFinder: Bool {
        !model.activeManualShortcuts.isEmpty || hasDockItems
    }

    private var hasDockItems: Bool {
        NumberKey.allCases.contains { key in
            model.dockItem(for: key) != nil
        }
    }

    private func windowShortcuts(for category: WindowActionCategory) -> [WindowShortcut] {
        model.windowManagementModel.windowShortcuts.filter { shortcut in
            shortcut.action.category == category
        }
    }

    private func menuLabel(_ title: String, shortcut: String?) -> String {
        guard let shortcut, !shortcut.isEmpty else { return title }
        return "\(title)    \(shortcut)"
    }
}
