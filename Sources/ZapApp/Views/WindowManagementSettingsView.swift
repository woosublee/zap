import SwiftUI
import ZapCore

struct WindowManagementSettingsView: View {
    @ObservedObject var model: WindowManagementModel
    let registrationError: String?
    let inputSourceRevision: Int

    init(model: WindowManagementModel, registrationError: String? = nil, inputSourceRevision: Int = 0) {
        self.model = model
        self.registrationError = registrationError
        self.inputSourceRevision = inputSourceRevision
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.large) {
            SettingsIssueBanner(messages: [
                registrationError,
                model.shortcutRegistrationError,
                model.windowManagementError
            ])

            shortcutsSection
        }
    }

    private var shortcutsSection: some View {
        SettingsCard(title: "Window Shortcuts") {
            if !model.accessibilityTrusted {
                accessibilityPermissionRow
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(WindowActionCategory.allCases, id: \.self) { category in
                    if let shortcuts = shortcutsByCategory[category], !shortcuts.isEmpty {
                        WindowShortcutCategoryGroup(
                            category: category,
                            shortcuts: shortcuts,
                            isLocked: !model.accessibilityTrusted,
                            inputSourceRevision: inputSourceRevision,
                            setEnabled: { shortcut, isEnabled in
                                model.setShortcutEnabled(action: shortcut.action, isEnabled: isEnabled)
                            },
                            setRecordingActive: { isRecording in
                                model.setShortcutRecordingActive(isRecording)
                            },
                            record: { shortcut, recordedShortcut in
                                model.setShortcut(
                                    action: shortcut.action,
                                    keyCode: recordedShortcut.keyCode,
                                    keyDisplayName: recordedShortcut.keyDisplayName,
                                    modifiers: recordedShortcut.modifiers
                                )
                            }
                        )
                    }
                }
            }
        } accessory: {
            HStack(spacing: ZapSpacing.medium) {
                Toggle("Enable window management shortcuts", isOn: Binding(
                    get: { model.isWindowManagementEnabled },
                    set: { model.setWindowManagementEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()

                Button("Reset to Defaults") {
                    model.resetShortcutsToDefaults()
                }
                .controlSize(.small)
            }
        }
    }

    private var accessibilityPermissionRow: some View {
        SettingsRow(
            title: AccessibilityPaneName.current,
            subtitle: "Required to move and resize windows.",
            leading: {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 24)
            },
            trailing: {
                Button("Grant…") {
                    model.requestAccessibilityPermission(
                        sourceFrame: PermissionGuideSourceFrame.atMouse
                    )
                    model.refreshAccessibilityPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        )
        .padding(.horizontal, 10)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var shortcutsByCategory: [WindowActionCategory: [WindowShortcut]] {
        Dictionary(grouping: model.windowShortcuts) { $0.action.category }
    }
}

private struct WindowShortcutCategoryGroup: View {
    let category: WindowActionCategory
    let shortcuts: [WindowShortcut]
    let isLocked: Bool
    let inputSourceRevision: Int
    let setEnabled: (WindowShortcut, Bool) -> Void
    let setRecordingActive: (Bool) -> Void
    let record: (WindowShortcut, RecordedShortcut) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(category.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    if index > 0 {
                        Divider()
                    }

                    WindowShortcutRowView(
                        shortcut: shortcut,
                        isLocked: isLocked,
                        inputSourceRevision: inputSourceRevision,
                        setEnabled: { isEnabled in setEnabled(shortcut, isEnabled) },
                        setRecordingActive: setRecordingActive,
                        record: { recordedShortcut in record(shortcut, recordedShortcut) }
                    )
                }
            }
        }
        .opacity(isLocked ? 0.72 : 1)
    }
}

private extension WindowActionCategory {
    var title: String {
        switch self {
        case .positioning: "Positioning"
        case .display: "Display"
        case .sizing: "Sizing"
        case .history: "History"
        }
    }
}
