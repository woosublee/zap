import SwiftUI
import ZapCore

struct WindowManagementSettingsView: View {
    @ObservedObject var model: WindowManagementModel
    let registrationError: String?

    init(model: WindowManagementModel, registrationError: String? = nil) {
        self.model = model
        self.registrationError = registrationError
    }

    var body: some View {
        Group {
            Section {
                Text("Manage shortcuts for moving and resizing the frontmost window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            accessibilityPermissionSection
            shortcutsSection
        }
    }

    private var accessibilityPermissionSection: some View {
        Section("Accessibility Permission") {
            if model.accessibilityTrusted {
                Label("Accessibility permission granted.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Zap needs Accessibility permission to move and resize windows.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Open Accessibility Settings") {
                    model.openAccessibilitySettings()
                }

                Button("Refresh Permission") {
                    model.refreshAccessibilityPermission()
                }

                Button("Request Permission") {
                    model.requestAccessibilityPermission()
                }
            }
        }
    }

    private var shortcutsSection: some View {
        Section("Shortcuts") {
            Toggle("Enable window management shortcuts", isOn: Binding(
                get: { model.isWindowManagementEnabled },
                set: { model.setWindowManagementEnabled($0) }
            ))

            Button("Reset to Defaults") {
                model.resetShortcutsToDefaults()
            }

            ForEach(model.windowShortcuts) { shortcut in
                WindowShortcutRowView(
                    shortcut: shortcut,
                    setEnabled: { isEnabled in
                        model.setShortcutEnabled(action: shortcut.action, isEnabled: isEnabled)
                    },
                    record: { recordedShortcut in
                        model.setShortcut(
                            action: shortcut.action,
                            keyCode: recordedShortcut.keyCode,
                            keyDisplayName: recordedShortcut.keyDisplayName,
                            modifiers: recordedShortcut.modifiers
                        )
                    }
                )
            }

            if let registrationError {
                Text(registrationError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let shortcutRegistrationError = model.shortcutRegistrationError {
                Text(shortcutRegistrationError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let windowManagementError = model.windowManagementError {
                Text(windowManagementError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
