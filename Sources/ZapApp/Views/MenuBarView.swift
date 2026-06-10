import ZapCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: ZapAppModel
    @ObservedObject var updateService: UpdateService
    let openSettings: () -> Void
    let openWindowManagementSettings: () -> Void
    let openAbout: () -> Void
    let quit: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 8)

            separator

            sectionLabel("Status")
            statusSection

            separator

            sectionLabel("Quick Launch")
            shortcutList

            separator

            sectionLabel("Window Management")
            MenuRow(label: "Window Shortcuts...", systemImage: "rectangle.3.group") {
                dismiss()
                openWindowManagementSettings()
            }

            separator

            sectionLabel("Maintenance")
            MenuRow(label: "Refresh Dock Apps", systemImage: "arrow.clockwise") {
                model.refreshDockItems()
            }
            MenuRow(label: "Check for Updates...", systemImage: "arrow.triangle.2.circlepath") {
                dismiss()
                updateService.checkForUpdates()
            }

            separator

            sectionLabel("App")
            MenuRow(label: "Settings...", systemImage: "gearshape", shortcut: "⌘,") {
                dismiss()
                openSettings()
            }
            MenuRow(label: AboutPresentation.aboutMenuLabel(appName: AboutPresentation.currentAppName), systemImage: "info.circle") {
                dismiss()
                openAbout()
            }
            MenuRow(label: "Quit \(AboutPresentation.currentAppName)", systemImage: nil, shortcut: "⌘Q") {
                quit()
            }
        }
        .padding(.vertical, 5)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(AboutPresentation.currentAppName)
                    .font(.system(size: 13, weight: .semibold))
                Text("Launch apps without leaving the keyboard")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatusRow(
                label: "Accessibility",
                status: model.windowManagementModel.accessibilityTrusted ? "Ready" : "Needs Permission",
                systemImage: model.windowManagementModel.accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                isWarning: !model.windowManagementModel.accessibilityTrusted
            )

            if let registrationError = model.registrationError {
                StatusRow(
                    label: "Shortcut registration",
                    status: registrationError,
                    systemImage: "exclamationmark.triangle.fill",
                    isWarning: true
                )
            }

            if let windowManagementError = model.windowManagementModel.windowManagementError {
                StatusRow(
                    label: "Window management",
                    status: windowManagementError,
                    systemImage: "exclamationmark.triangle.fill",
                    isWarning: true
                )
            }
        }
    }

    private var shortcutList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isFinderShortcutEnabled {
                MenuRow(
                    label: "Finder",
                    systemImage: "folder",
                    shortcut: model.finderShortcutTitle
                ) {
                    model.activateFinder()
                }
            }

            ForEach(model.activeManualShortcuts) { shortcut in
                MenuRow(
                    label: shortcut.name,
                    systemImage: "app.dashed",
                    shortcut: shortcut.shortcutTitle
                ) {
                    model.activateManualShortcut(id: shortcut.id)
                }
            }

            ForEach(NumberKey.allCases) { key in
                if let item = model.dockItem(for: key) {
                    MenuRow(
                        label: item.name,
                        systemImage: "app.dashed",
                        shortcut: model.shortcutTitle(for: key)
                    ) {
                        model.activateDockItem(for: key)
                    }
                }
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 5)
            .padding(.bottom, 3)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(height: 0.5)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
    }
}

private struct StatusRow: View {
    let label: String
    let status: String
    let systemImage: String
    let isWarning: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isWarning ? .orange : .green)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(status)
                .font(.caption)
                .foregroundStyle(isWarning ? .orange : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 5)
    }
}

private struct MenuRow: View {
    let label: String
    let systemImage: String?
    var shortcut: String? = nil
    var disabled = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Group {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .medium))
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 14)
                .foregroundStyle(hovering ? Color.white : Color.secondary)

                Text(label)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(hovering ? Color.white : Color.primary)

                Spacer(minLength: 8)

                if let shortcut {
                    ShortcutKeycapGroupView(shortcut: shortcut, isDisabled: disabled)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(hovering ? Color.accentColor : Color.clear)
            )
            .padding(.horizontal, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.48 : 1)
        .onHover { value in
            guard !disabled else { return }
            hovering = value
        }
    }
}
