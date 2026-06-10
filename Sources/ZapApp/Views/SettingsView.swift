import AppKit
import ZapCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: ZapAppModel
    @ObservedObject var updateService: UpdateService
    @Binding var showMenuBarIcon: Bool
    @State private var selectedMode = SettingsMode.automatic
    @State private var recordingShortcut: ManualShortcut?

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $selectedMode) {
                    ForEach(SettingsMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            switch selectedMode {
            case .automatic:
                automaticShortcutsSection
                automaticSection
            case .manual:
                manualSection
            case .windowManagement:
                WindowManagementSettingsView(model: model.windowManagementModel, registrationError: model.registrationError)
            }

            behaviorSection
            updatesSection
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 500, height: 640)
        .sheet(item: $recordingShortcut) { shortcut in
            ShortcutRecorderView(
                appName: shortcut.name,
                onRecord: { recordedShortcut in
                    model.setManualShortcut(
                        id: shortcut.id,
                        keyCode: recordedShortcut.keyCode,
                        keyDisplayName: recordedShortcut.keyDisplayName,
                        modifiers: recordedShortcut.modifiers
                    )
                    recordingShortcut = nil
                },
                onCancel: {
                    recordingShortcut = nil
                }
            )
        }
    }

    private var menuBarIconBinding: Binding<Bool> {
        Binding(
            get: { showMenuBarIcon },
            set: { newValue in
                showMenuBarIcon = newValue
                AppActivationPolicy.apply(showMenuBarIcon: newValue)
            }
        )
    }

    private var automaticShortcutsSection: some View {
        Section("Shortcuts") {
            dockModifierSelector
            Toggle(isOn: $model.isFinderShortcutEnabled) {
                HStack(spacing: 4) {
                    Text("Finder shortcut")
                    Text("(\(model.finderShortcutKeyTitle))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            if let registrationError = model.registrationError {
                Text(registrationError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var dockModifierSelector: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dock app shortcuts")
                Text("Choose the modifier keys used with 1–9")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 5) {
                ForEach(ShortcutModifier.allCases) { modifier in
                    ModifierKeyButton(
                        modifier: modifier,
                        isSelected: model.selectedModifiers.contains(modifier)
                    ) {
                        model.setModifier(modifier, isEnabled: !model.selectedModifiers.contains(modifier))
                    }
                }

                Text("+ 1–9")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var automaticSection: some View {
        Section {
            Text("Pinned Dock apps mapped to 1–9.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: automaticShortcutColumns, alignment: .leading, spacing: 8) {
                if model.isFinderShortcutEnabled {
                    ShortcutListRow(shortcut: model.finderShortcutTitle, title: "Finder")
                }

                ForEach(NumberKey.allCases) { key in
                    ShortcutListRow(
                        shortcut: model.shortcutTitle(for: key),
                        title: model.dockItem(for: key)?.name ?? "Empty",
                        isEmpty: model.dockItem(for: key) == nil
                    )
                }
            }
        } header: {
            HStack {
                Text("Automatic Dock Apps")
                Spacer()
                Button {
                    model.refreshDockItems()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh Dock Apps")
            }
        }
    }

    private var automaticShortcutColumns: [GridItem] {
        [
            GridItem(.flexible(), alignment: .leading),
            GridItem(.flexible(), alignment: .leading)
        ]
    }

    private var behaviorSection: some View {
        Section("Behavior") {
            Toggle("Launch at login", isOn: $model.startAtLogin)
            Toggle("Show menu bar icon", isOn: menuBarIconBinding)

            if let loginItemError = model.loginItemError {
                Text(loginItemError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var updatesSection: some View {
        Section("Updates") {
            Toggle("Automatically check for updates", isOn: $updateService.automaticallyChecksForUpdates)

            Button("Check for Updates Now") {
                updateService.checkForUpdates()
            }

            Text("Updates are delivered with Sparkle and verified using EdDSA signatures.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var manualSection: some View {
        Section("Manual App Shortcuts") {
            Text("Add apps and assign custom global shortcuts.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Add App Shortcut...") {
                addManualShortcut()
            }

            if model.manualShortcuts.isEmpty {
                Text("No manual shortcuts")
                    .foregroundStyle(.secondary)
            }

            ForEach(model.manualShortcuts) { shortcut in
                ManualShortcutRow(
                    shortcut: shortcut,
                    setEnabled: { model.setManualShortcutEnabled(id: shortcut.id, isEnabled: $0) },
                    record: { recordingShortcut = shortcut },
                    remove: { model.removeManualShortcut(id: shortcut.id) }
                )
            }

            if let registrationError = model.registrationError {
                Text(registrationError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func addManualShortcut() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            model.addManualShortcut(appURL: url)
            selectedMode = .manual
        }
    }
}

enum SettingsMode: String, CaseIterable, Identifiable {
    case automatic
    case manual
    case windowManagement

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .manual: "Manual"
        case .windowManagement: "Window Management"
        }
    }
}

private struct ModifierKeyButton: View {
    let modifier: ShortcutModifier
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(modifier.symbol)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .frame(width: 26, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(modifier.title)
    }
}

private struct ShortcutListRow: View {
    let shortcut: String
    let title: String
    var isEmpty = false

    var body: some View {
        HStack(spacing: 7) {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .frame(width: 72, alignment: .leading)
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isEmpty ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ManualShortcutRow: View {
    let shortcut: ManualShortcut
    let setEnabled: (Bool) -> Void
    let record: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(shortcut.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { shortcut.isEnabled },
                    set: setEnabled
                ))
                .labelsHidden()
                .disabled(shortcut.shortcutTitle == nil)
            }

            HStack {
                Text(shortcut.shortcutTitle ?? "Not set")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(shortcut.shortcutTitle == nil ? .secondary : .primary)
                Spacer()
                Button("Record") {
                    record()
                }
                Button(role: .destructive) {
                    remove()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}
