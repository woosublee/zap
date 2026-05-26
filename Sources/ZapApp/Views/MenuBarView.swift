import ZapCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: ZapAppModel
    let openSettings: () -> Void
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

            if let registrationError = model.registrationError {
                Text(registrationError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                separator
            }

            shortcutList

            separator

            MenuRow(label: "Refresh Dock Apps", systemImage: "arrow.clockwise") {
                model.refreshDockItems()
            }
            MenuRow(label: "Settings...", systemImage: "gearshape", shortcut: "⌘,") {
                dismiss()
                openSettings()
            }
            MenuRow(label: AboutPresentation.aboutMenuLabel(appName: AboutPresentation.currentAppName), systemImage: "info.circle") {
                dismiss()
                openAbout()
            }

            separator

            MenuRow(label: "Quit \(AboutPresentation.currentAppName)", systemImage: nil, shortcut: "⌘Q") {
                quit()
            }
        }
        .padding(.vertical, 5)
        .frame(width: 320)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AboutPresentation.currentAppName)
                .font(.system(size: 13, weight: .semibold))
            Text("Launch Dock apps with number shortcuts")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
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
                let item = model.dockItem(for: key)
                MenuRow(
                    label: item?.name ?? "Dock slot \(key.rawValue)",
                    systemImage: item == nil ? "minus.circle" : "app.dashed",
                    shortcut: model.shortcutTitle(for: key),
                    disabled: item == nil
                ) {
                    model.activateDockItem(for: key)
                }
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(height: 0.5)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
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
                    Text(shortcut)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(hovering ? Color.white.opacity(0.85) : Color.secondary)
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
        .opacity(disabled ? 0.5 : 1)
        .onHover { value in
            guard !disabled else { return }
            hovering = value
        }
    }
}
