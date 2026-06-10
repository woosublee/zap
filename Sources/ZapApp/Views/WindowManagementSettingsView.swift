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
            shortcutsSection
        }
    }

    private var shortcutsSection: some View {
        SettingsCard(
            title: "Shortcuts",
            subtitle: "Grouped by what each shortcut changes, so the full set stays scannable."
        ) {
            HStack(spacing: 12) {
                Toggle("Enable window management shortcuts", isOn: Binding(
                    get: { model.isWindowManagementEnabled },
                    set: { model.setWindowManagementEnabled($0) }
                ))
                .toggleStyle(.switch)

                Spacer()

                Button("Reset to Defaults") {
                    model.resetShortcutsToDefaults()
                }
            }

            if !model.accessibilityTrusted {
                Label("Grant Accessibility in Setting to enable and run window shortcuts.", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 12) {
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

            shortcutErrorMessages
        }
    }

    private var shortcutsByCategory: [WindowActionCategory: [WindowShortcut]] {
        Dictionary(grouping: model.windowShortcuts) { $0.action.category }
    }

    @ViewBuilder
    private var shortcutErrorMessages: some View {
        if registrationError != nil || model.shortcutRegistrationError != nil || model.windowManagementError != nil {
            VStack(alignment: .leading, spacing: 6) {
                if let registrationError {
                    Label(registrationError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let shortcutRegistrationError = model.shortcutRegistrationError {
                    Label(shortcutRegistrationError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let windowManagementError = model.windowManagementError {
                    Label(windowManagementError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
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

    private let shortcutColumns = [
        GridItem(.adaptive(minimum: 240), spacing: 8, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(category.title)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
            }

            LazyVGrid(columns: shortcutColumns, alignment: .leading, spacing: 8) {
                ForEach(shortcuts) { shortcut in
                    WindowShortcutRowView(
                        shortcut: shortcut,
                        isLocked: isLocked,
                        inputSourceRevision: inputSourceRevision,
                        setEnabled: { isEnabled in setEnabled(shortcut, isEnabled) },
                        setRecordingActive: setRecordingActive,
                        record: { recordedShortcut in record(shortcut, recordedShortcut) }
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    var systemImage: String {
        switch self {
        case .positioning: "rectangle.split.3x3"
        case .display: "display.2"
        case .sizing: "arrow.up.left.and.arrow.down.right"
        case .history: "arrow.uturn.backward.circle"
        }
    }
}
