import AppKit
import SnapCore
import SwiftUI

struct RecordedShortcut {
    let keyCode: UInt32
    let keyDisplayName: String
    let modifiers: Set<ShortcutModifier>
}

struct ShortcutRecorderView: View {
    let appName: String
    let onRecord: (RecordedShortcut) -> Void
    let onCancel: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Record Shortcut")
                .font(.headline)
            Text("Press the shortcut you want to use for \(appName).")
                .foregroundStyle(.secondary)

            ShortcutCaptureView { event in
                handle(event)
            }
            .frame(height: 72)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
            )
            .overlay {
                Text("Press shortcut now")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }

        let modifiers = ShortcutModifier.modifiers(from: event.modifierFlags)
        guard !modifiers.isEmpty else {
            errorMessage = "Select at least one modifier key."
            return
        }

        onRecord(RecordedShortcut(
            keyCode: UInt32(event.keyCode),
            keyDisplayName: Self.displayName(for: event),
            modifiers: modifiers
        ))
    }

    private static func displayName(for event: NSEvent) -> String {
        ShortcutKeyDisplay.displayName(
            forKeyCode: UInt32(event.keyCode),
            fallback: event.charactersIgnoringModifiers
        )
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        KeyCaptureView(onKeyDown: onKeyDown)
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class KeyCaptureView: NSView {
    var onKeyDown: (NSEvent) -> Void

    init(onKeyDown: @escaping (NSEvent) -> Void) {
        self.onKeyDown = onKeyDown
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown(event)
    }
}

private extension ShortcutModifier {
    static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<ShortcutModifier> {
        var modifiers = Set<ShortcutModifier>()
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }
}
