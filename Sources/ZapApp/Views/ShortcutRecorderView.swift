import AppKit
import ZapCore
import SwiftUI

struct RecordedShortcut {
    let keyCode: UInt32
    let keyDisplayName: String
    let modifiers: Set<ShortcutModifier>
}

struct ShortcutRecorderView: View {
    let title: String
    let instructions: String
    let capturePrompt: String
    let onRecord: (RecordedShortcut) -> Void
    let onCancel: () -> Void

    init(appName: String, onRecord: @escaping (RecordedShortcut) -> Void, onCancel: @escaping () -> Void) {
        self.title = "Record App Shortcut"
        self.instructions = "Press the global shortcut that opens \(appName)."
        self.capturePrompt = "Press app shortcut"
        self.onRecord = onRecord
        self.onCancel = onCancel
    }

    init(windowActionName: String, onRecord: @escaping (RecordedShortcut) -> Void, onCancel: @escaping () -> Void) {
        self.title = "Record Window Shortcut"
        self.instructions = "Press the global shortcut that runs \(windowActionName)."
        self.capturePrompt = "Press window shortcut"
        self.onRecord = onRecord
        self.onCancel = onCancel
    }

    @State private var errorMessage: String?
    @State private var recordingPulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(.headline, design: .default, weight: .semibold))
                Text(instructions)
                    .foregroundStyle(.secondary)
            }

            ShortcutCaptureView { event in
                handle(event)
            }
            .frame(height: 86)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.accentColor.opacity(recordingPulse ? 0.70 : 0.28), lineWidth: 1)
            )
            .overlay {
                VStack(spacing: 9) {
                    HStack(spacing: 5) {
                        ShortcutKeycapView(label: "Modifier", isSelected: true)
                        ShortcutKeycapView(label: capturePrompt)
                    }
                    Text("Press any modifier key plus a key. Esc cancels.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    recordingPulse = true
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(width: 400)
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

    private var keyDownMonitor: Any?

    init(onKeyDown: @escaping (NSEvent) -> Void) {
        self.onKeyDown = onKeyDown
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        removeKeyDownMonitor()
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeKeyDownMonitor()
            return
        }
        installKeyDownMonitor()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown(event)
    }

    private func installKeyDownMonitor() {
        guard keyDownMonitor == nil else { return }
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.window != nil else { return event }
            onKeyDown(event)
            return nil
        }
    }

    private func removeKeyDownMonitor() {
        guard let monitor = keyDownMonitor else { return }
        NSEvent.removeMonitor(monitor)
        keyDownMonitor = nil
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
