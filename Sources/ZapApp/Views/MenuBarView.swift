import SwiftUI
import ZapCore

struct MenuBarView: View {
    @ObservedObject var model: ZapAppModel
    @ObservedObject var updateService: UpdateService
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
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
