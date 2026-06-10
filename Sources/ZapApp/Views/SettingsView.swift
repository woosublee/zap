import AppKit
import ZapCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: ZapAppModel
    @ObservedObject var updateService: UpdateService
    @Binding var showMenuBarIcon: Bool
    @State private var selectedMode: SettingsMode
    @State private var recordingShortcut: ManualShortcut?

    init(
        model: ZapAppModel,
        updateService: UpdateService,
        showMenuBarIcon: Binding<Bool>,
        initialMode: SettingsMode = .automatic
    ) {
        self.model = model
        self.updateService = updateService
        _showMenuBarIcon = showMenuBarIcon
        _selectedMode = State(initialValue: initialMode)
    }

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: ZapSpacing.large) {
                    switch selectedMode {
                    case .automatic:
                        automaticShortcutsSection
                        automaticSection
                    case .manual:
                        manualSection
                    case .windowManagement:
                        WindowManagementSettingsView(
                            model: model.windowManagementModel,
                            registrationError: model.registrationError,
                            inputSourceRevision: model.inputSourceRevision
                        )
                    case .setting:
                        settingSection
                    case .about:
                        aboutSection
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
        }
        .frame(width: 820, height: 640)
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

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(AboutPresentation.currentAppName)
                        .font(.system(size: 13, weight: .semibold))
                    Text("Keyboard-first control")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 12)

            sidebarSection(title: "Shortcuts", modes: [.automatic, .manual, .windowManagement])

            sidebarSection(title: "System", modes: [.setting, .about])
                .padding(.top, 10)

            Spacer()
        }
        .padding(14)
        .frame(width: 216)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.bar)
    }

    private func sidebarSection(title: String, modes: [SettingsMode]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 10)

            ForEach(modes) { mode in
                SettingsSidebarItem(
                    mode: mode,
                    isSelected: selectedMode == mode
                ) {
                    selectedMode = mode
                }
            }
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

    private var settingSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.large) {
            permissionsSection
            behaviorSection
            updatesSection
        }
    }

    private var aboutSection: some View {
        HStack {
            Spacer(minLength: 0)
            AboutView(presentation: AboutPresentation(appName: AboutPresentation.currentAppName, info: AboutInfo.current))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var permissionsSection: some View {
        SettingsCard(title: "Permissions") {
            SettingsRow(
                title: "Accessibility",
                subtitle: "Allow Zap to move and resize windows.",
                leading: {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)
                },
                trailing: {
                    if model.windowManagementModel.accessibilityTrusted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .font(.system(.callout, design: .default, weight: .semibold))
                            .foregroundStyle(.green)
                    } else {
                        Button("Request") {
                            model.windowManagementModel.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            )
        }
    }

    private var automaticShortcutsSection: some View {
        SettingsCard(title: "Shortcuts", subtitle: "Choose the global modifiers Zap uses for Dock and Finder actions.") {
            dockModifierSelector

            Toggle("Finder shortcut", isOn: $model.isFinderShortcutEnabled)
                .toggleStyle(.switch)

            if let registrationError = model.registrationError {
                Label(registrationError, systemImage: "exclamationmark.triangle.fill")
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

                ShortcutKeycapView(label: "1–9")
            }
        }
    }

    private var automaticSection: some View {
        SettingsCard(title: "Automatic Dock Apps", subtitle: "Pinned Dock apps mapped to number keys.") {
            HStack {
                Text("Refresh the Dock when pinned apps change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.refreshDockItems()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
            }

            LazyVGrid(columns: automaticShortcutColumns, alignment: .leading, spacing: 8) {
                ShortcutListRow(
                    shortcut: model.finderShortcutTitle,
                    title: "Finder",
                    isDisabled: !model.isFinderShortcutEnabled
                )

                ForEach(NumberKey.allCases) { key in
                    ShortcutListRow(
                        shortcut: model.shortcutTitle(for: key),
                        title: model.dockItem(for: key)?.name ?? "Empty",
                        isEmpty: model.dockItem(for: key) == nil
                    )
                }
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
        SettingsCard(title: "Behavior") {
            Toggle("Launch at login", isOn: $model.startAtLogin)
            Toggle("Show menu bar icon", isOn: menuBarIconBinding)

            if let loginItemError = model.loginItemError {
                Label(loginItemError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var updatesSection: some View {
        SettingsCard(title: "Updates") {
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
        SettingsCard(title: "Manual App Shortcuts", subtitle: "Add apps and assign custom global shortcuts.") {
            Button("Add App Shortcut...") {
                addManualShortcut()
            }

            if model.manualShortcuts.isEmpty {
                Text("No manual shortcuts")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
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
                Label(registrationError, systemImage: "exclamationmark.triangle.fill")
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
    case setting
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .manual: "Manual"
        case .windowManagement: "Window Management"
        case .setting: "Setting"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .automatic: "sparkle"
        case .manual: "keyboard"
        case .windowManagement: "rectangle.3.group"
        case .setting: "gearshape"
        case .about: "info.circle"
        }
    }
}

private struct SettingsSidebarItem: View {
    let mode: SettingsMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                Text(mode.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct ModifierKeyButton: View {
    let modifier: ShortcutModifier
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ShortcutKeycapView(label: modifier.symbol, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .help(modifier.title)
    }
}

private struct ShortcutListRow: View {
    let shortcut: String
    let title: String
    var isEmpty = false
    var isDisabled = false

    var body: some View {
        HStack(spacing: 8) {
            ShortcutKeycapGroupView(shortcut: shortcut, isDisabled: isEmpty || isDisabled)
                .frame(width: 80, alignment: .leading)
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isEmpty || isDisabled ? .secondary : .primary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(isEmpty ? 0.025 : 0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .opacity(isDisabled ? 0.62 : 1)
    }
}

private struct ManualShortcutRow: View {
    let shortcut: ManualShortcut
    let setEnabled: (Bool) -> Void
    let record: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(shortcut.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                record()
            } label: {
                ShortcutKeycapGroupView(shortcut: shortcut.shortcutTitle, isDisabled: !shortcut.isEnabled)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Record shortcut for \(shortcut.name)")
            .help("Record shortcut")

            Toggle("", isOn: Binding(
                get: { shortcut.isEnabled },
                set: setEnabled
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(shortcut.shortcutTitle == nil)

            Button(role: .destructive) {
                remove()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }
}
