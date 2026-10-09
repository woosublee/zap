import AppKit
import ZapCore
import SwiftUI
import UniformTypeIdentifiers

final class SettingsNavigationState: ObservableObject {
    @Published var selectedMode: SettingsMode {
        didSet {
            defaults.set(selectedMode.rawValue, forKey: SettingsMode.lastModeDefaultsKey)
        }
    }

    private let defaults: UserDefaults

    init(selectedMode: SettingsMode = .general, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectedMode = selectedMode
    }
}

struct SettingsView: View {
    @ObservedObject var model: ZapAppModel
    @ObservedObject var updateService: UpdateService
    @Binding var showMenuBarIcon: Bool
    @ObservedObject private var navigationState: SettingsNavigationState
    @State private var recordingShortcut: ManualShortcut?
    @State private var isRecordingActiveApplicationToggleShortcut = false

    init(
        model: ZapAppModel,
        updateService: UpdateService,
        showMenuBarIcon: Binding<Bool>,
        initialMode: SettingsMode = .general,
        navigationState: SettingsNavigationState? = nil
    ) {
        self.model = model
        self.updateService = updateService
        _showMenuBarIcon = showMenuBarIcon
        self.navigationState = navigationState ?? SettingsNavigationState(selectedMode: initialMode)
    }

    private var selectedMode: SettingsMode {
        get { navigationState.selectedMode }
        nonmutating set { navigationState.selectedMode = newValue }
    }

    var body: some View {
        HStack(spacing: 0) {
            settingsSidebar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: ZapSpacing.large) {
                    switch selectedMode {
                    case .general:
                        SettingsIssueBanner(messages: [model.registrationError])
                        generalSection
                    case .apps:
                        SettingsIssueBanner(messages: [model.registrationError])
                        dockAppsSection
                        customAppsSection
                    case .windows:
                        WindowManagementSettingsView(
                            model: model.windowManagementModel,
                            registrationError: model.registrationError,
                            inputSourceRevision: model.inputSourceRevision
                        )
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
        .sheet(
            isPresented:
                $isRecordingActiveApplicationToggleShortcut
        ) {
            ShortcutRecorderView(
                activeApplicationToggleOnRecord: { recordedShortcut in
                    model.setActiveApplicationToggleShortcut(
                        keyCode: recordedShortcut.keyCode,
                        keyDisplayName: recordedShortcut.keyDisplayName,
                        modifiers: recordedShortcut.modifiers
                    )
                    isRecordingActiveApplicationToggleShortcut = false
                },
                onCancel: {
                    isRecordingActiveApplicationToggleShortcut = false
                }
            )
        }
        .onAppear {
            refreshAccessibilityPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityPermission()
        }
    }

    private func refreshAccessibilityPermission() {
        model.windowManagementModel.refreshAccessibilityPermission()
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 5) {
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
            .padding(.bottom, 15)

            ForEach(SettingsMode.allCases) { mode in
                SettingsSidebarItem(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    action: { selectedMode = mode }
                ) {
                    if mode == .windows {
                        AccessibilityWarningBadge(model: model.windowManagementModel)
                    }
                }
            }

            Spacer()

            Text(sidebarVersionLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
        }
        .padding(14)
        .frame(width: 216)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.bar)
    }

    private var sidebarVersionLine: String {
        AboutPresentation(appName: AboutPresentation.currentAppName, info: AboutInfo.current).versionLine
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

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.large) {
            shortcutControlsSection
            behaviorSection
            if AppDistribution.current.supportsInAppUpdates {
                updatesSection
            }
        }
    }

    private var shortcutControlsSection: some View {
        SettingsCard(title: "Shortcut Controls") {
            SettingsRow(
                title: "Toggle Zap for Current App",
                subtitle:
                    "Disable or re-enable Zap shortcuts for the currently active app.",
                leading: {
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24)
                },
                trailing: {
                    HStack(spacing: ZapSpacing.medium) {
                        Button {
                            isRecordingActiveApplicationToggleShortcut = true
                        } label: {
                            ShortcutKeycapGroupView(shortcut: model.activeApplicationToggleShortcut.shortcutTitle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "Record Toggle Zap for Current App shortcut"
                        )
                        .help("Record shortcut")

                        if model.activeApplicationToggleShortcut.canRegister {
                            Button("Clear", role: .destructive) {
                                model.clearActiveApplicationToggleShortcut()
                            }
                            .controlSize(.small)
                        }
                    }
                }
            )
        }
    }

    private var dockModifierSelector: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Modifier")

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
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dockAppsSection: some View {
        SettingsCard(title: "Dock Apps", subtitle: "Your first nine pinned Dock apps, in order.") {
            dockModifierSelector

            LazyVGrid(columns: automaticShortcutColumns, alignment: .leading, spacing: 8) {
                ShortcutListRow(
                    shortcut: model.finderShortcutTitle,
                    title: "Finder",
                    isDisabled: !model.isFinderShortcutEnabled,
                    isOn: $model.isFinderShortcutEnabled
                )

                ForEach(NumberKey.allCases) { key in
                    ShortcutListRow(
                        shortcut: model.shortcutTitle(for: key),
                        title: model.dockItem(for: key)?.name ?? "Empty",
                        isEmpty: model.dockItem(for: key) == nil
                    )
                }
            }
        } accessory: {
            Button {
                model.refreshDockItems()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
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

            HStack {
                Spacer()
                Button("Check Now") {
                    updateService.checkForUpdates()
                }
            }
        }
    }

    private var customAppsSection: some View {
        SettingsCard(title: "Custom Apps", subtitle: "Any app, any shortcut.") {
            if model.manualShortcuts.isEmpty {
                Text("No custom apps yet")
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
        } accessory: {
            Button("Add App…") {
                addManualShortcut()
            }
            .controlSize(.small)
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
            selectedMode = .apps
        }
    }
}

enum SettingsMode: String, CaseIterable, Identifiable {
    case general
    case apps
    case windows

    static let lastModeDefaultsKey = "settings_last_mode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .apps: "Apps"
        case .windows: "Windows"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .apps: "square.grid.2x2"
        case .windows: "rectangle.3.group"
        }
    }

    static func initial(requested: SettingsMode?, storedRawValue: String?) -> SettingsMode {
        requested ?? storedRawValue.flatMap(SettingsMode.init(rawValue:)) ?? .general
    }
}

private struct SettingsSidebarItem<Accessory: View>: View {
    let mode: SettingsMode
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let accessory: Accessory

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
                accessory
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
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

private struct AccessibilityWarningBadge: View {
    @ObservedObject var model: WindowManagementModel

    var body: some View {
        if !model.accessibilityTrusted {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .help("Accessibility permission required")
                .accessibilityLabel("Accessibility permission required")
        }
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
    var isOn: Binding<Bool>? = nil

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                ShortcutKeycapGroupView(shortcut: shortcut, isDisabled: isEmpty || isDisabled)
                    .frame(width: 80, alignment: .leading)
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isEmpty || isDisabled ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(isDisabled ? 0.62 : 1)

            if let isOn {
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .accessibilityLabel("Finder shortcut")
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(isEmpty ? 0.025 : 0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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
