import SwiftUI
import ZapCore

struct WindowShortcutRowView: View {
    let shortcut: WindowShortcut
    var isLocked = false
    let inputSourceRevision: Int
    let setEnabled: (Bool) -> Void
    let setRecordingActive: (Bool) -> Void
    let record: (RecordedShortcut) -> Void

    @State private var isRecording = false

    private var shortcutTitle: String? {
        _ = inputSourceRevision
        return WindowShortcutDisplay.shortcutTitle(for: shortcut)
    }

    private var canRecordShortcut: Bool {
        !isLocked && shortcut.isEnabled
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            WindowActionDiagramView(action: shortcut.action)

            Text(shortcut.action.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                guard canRecordShortcut else { return }
                setRecordingActive(true)
                isRecording = true
            } label: {
                ShortcutKeycapGroupView(shortcut: shortcutTitle, isDisabled: !canRecordShortcut)
            }
            .buttonStyle(.plain)
            .disabled(!canRecordShortcut)
            .accessibilityLabel("Record shortcut for \(shortcut.action.title)")
            .help("Record shortcut")

            Button {
                setEnabled(!shortcut.isEnabled)
            } label: {
                Image(systemName: shortcut.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(shortcut.isEnabled ? Color.accentColor : Color.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLocked || shortcutTitle == nil)
            .accessibilityLabel(shortcut.isEnabled ? "Disable \(shortcut.action.title)" : "Enable \(shortcut.action.title)")
            .help(shortcut.isEnabled ? "Disable shortcut" : "Enable shortcut")
        }
        .padding(.vertical, 8)
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
            .onDisappear {
                setRecordingActive(false)
            }
        }
    }
}

struct WindowActionDiagramView: View {
    let action: WindowAction

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.primary.opacity(0.16), lineWidth: 1)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            diagramContent
                .padding(4)
        }
        .frame(width: 34, height: 28)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var diagramContent: some View {
        switch action.category {
        case .positioning:
            GeometryReader { proxy in
                let rect = highlightedRect(in: proxy.size)
                ZStack(alignment: .topLeading) {
                    GridLines()
                        .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.accentColor.opacity(0.65))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                }
            }
        case .display:
            HStack(spacing: 2) {
                Image(systemName: action == .nextDisplay ? "display" : "display")
                Image(systemName: action == .nextDisplay ? "arrow.right" : "arrow.left")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.accentColor)
        case .sizing:
            Image(systemName: sizingSymbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        case .history:
            Image(systemName: action == .undo ? "arrow.uturn.backward" : "arrow.uturn.forward")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var sizingSymbol: String {
        switch action {
        case .larger: "arrow.up.left.and.arrow.down.right"
        case .smaller: "arrow.down.right.and.arrow.up.left"
        case .nextThird: "rectangle.split.3x1"
        case .previousThird: "rectangle.split.3x1"
        default: "arrow.up.left.and.arrow.down.right"
        }
    }

    private func highlightedRect(in size: CGSize) -> CGRect {
        let thirdWidth = size.width / 3
        let thirdHeight = size.height / 3
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2

        switch action {
        case .center:
            return CGRect(x: thirdWidth, y: thirdHeight, width: thirdWidth, height: thirdHeight)
        case .fullscreen:
            return CGRect(origin: .zero, size: size)
        case .leftHalf:
            return CGRect(x: 0, y: 0, width: halfWidth, height: size.height)
        case .rightHalf:
            return CGRect(x: halfWidth, y: 0, width: halfWidth, height: size.height)
        case .topHalf:
            return CGRect(x: 0, y: 0, width: size.width, height: halfHeight)
        case .bottomHalf:
            return CGRect(x: 0, y: halfHeight, width: size.width, height: halfHeight)
        case .upperLeft:
            return CGRect(x: 0, y: 0, width: halfWidth, height: halfHeight)
        case .upperRight:
            return CGRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight)
        case .lowerLeft:
            return CGRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight)
        case .lowerRight:
            return CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight)
        default:
            return CGRect(x: thirdWidth, y: thirdHeight, width: thirdWidth, height: thirdHeight)
        }
    }
}

private struct GridLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let thirdWidth = rect.width / 3
        let thirdHeight = rect.height / 3

        for index in 1...2 {
            let x = rect.minX + thirdWidth * CGFloat(index)
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))

            let y = rect.minY + thirdHeight * CGFloat(index)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}

private extension WindowAction {
    var supportingText: String {
        switch self {
        case .center: "Place the window in the middle of the current display."
        case .fullscreen: "Fill the visible area of the current display."
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf: "Snap to a half of the current display."
        case .upperLeft, .upperRight, .lowerLeft, .lowerRight: "Snap to a corner quadrant."
        case .nextDisplay: "Move to the next display."
        case .previousDisplay: "Move to the previous display."
        case .nextThird: "Cycle forward through third-width layouts."
        case .previousThird: "Cycle backward through third-width layouts."
        case .larger: "Grow the current window."
        case .smaller: "Shrink the current window."
        case .undo: "Restore the previous window frame."
        case .redo: "Reapply the restored window frame."
        }
    }
}
