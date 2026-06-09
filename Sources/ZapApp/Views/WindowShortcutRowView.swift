import SwiftUI
import ZapCore

struct WindowShortcutRowView: View {
    let shortcut: WindowShortcut
    let setEnabled: (Bool) -> Void
    let record: (RecordedShortcut) -> Void

    @State private var isRecording = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(shortcut.action.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
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
                    isRecording = true
                }
                Button("Disable") {
                    setEnabled(false)
                }
                .disabled(shortcut.shortcutTitle == nil || !shortcut.isEnabled)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $isRecording) {
            ShortcutRecorderView(
                windowActionName: shortcut.action.title,
                onRecord: { recordedShortcut in
                    record(recordedShortcut)
                    isRecording = false
                },
                onCancel: {
                    isRecording = false
                }
            )
        }
    }
}
