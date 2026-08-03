import AppKit
import SwiftUI

final class ShortcutHUDMaterialView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func configure() {
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        alphaValue = 0.72
        isEmphasized = false
        wantsLayer = true
        layer?.cornerRadius = ShortcutHUDLayout.cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }
}

struct ShortcutHUDMaterialBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> ShortcutHUDMaterialView {
        ShortcutHUDMaterialView(frame: .zero)
    }

    func updateNSView(_ nsView: ShortcutHUDMaterialView, context: Context) {
        nsView.configure()
    }
}

struct ShortcutHUDView: View {
    @ObservedObject var model: ShortcutHUDViewModel

    var body: some View {
        ZStack {
            if let presentation = model.presentation,
               let icon = model.icon {
                card(presentation: presentation, icon: icon)
            }
        }
        .frame(
            width: ShortcutHUDLayout.panelSize.width,
            height: ShortcutHUDLayout.panelSize.height
        )
        .opacity(model.opacity)
        .scaleEffect(model.scale)
        .accessibilityHidden(true)
    }

    private func card(
        presentation: ShortcutHUDPresentation,
        icon: NSImage
    ) -> some View {
        ZStack {
            if presentation.usesOpaqueBackground {
                RoundedRectangle(
                    cornerRadius: ShortcutHUDLayout.cornerRadius,
                    style: .continuous
                )
                .fill(Color.black.opacity(0.90))
            } else {
                ShortcutHUDMaterialBackground()
                    .frame(
                        width: ShortcutHUDLayout.cardSize.width,
                        height: ShortcutHUDLayout.cardSize.height
                    )
            }

            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(
                    width: ShortcutHUDLayout.iconSize.width,
                    height: ShortcutHUDLayout.iconSize.height
                )
                .overlay(alignment: .bottomTrailing) {
                    badge(presentation.badge)
                        .offset(x: 8, y: 8)
                }
        }
        .frame(
            width: ShortcutHUDLayout.cardSize.width,
            height: ShortcutHUDLayout.cardSize.height
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: ShortcutHUDLayout.cornerRadius,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.72), location: 0),
                        .init(color: .white.opacity(0.14), location: 0.32),
                        .init(
                            color: Color(nsColor: .systemBlue).opacity(0.18),
                            location: 0.68
                        ),
                        .init(color: .white.opacity(0.34), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: ShortcutHUDLayout.glassBorderWidth
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: ShortcutHUDLayout.innerHighlightCornerRadius,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(
                    presentation.usesOpaqueBackground ? 0.10 : 0.07
                ),
                lineWidth: 1
            )
            .padding(ShortcutHUDLayout.innerHighlightInset)
        }
    }

    @ViewBuilder
    private func badge(_ badge: ShortcutHUDBadge) -> some View {
        switch badge {
        case .none:
            EmptyView()
        case .disabled:
            badgeCircle(systemName: "minus", color: Color(nsColor: .systemRed))
        case .enabled:
            badgeCircle(systemName: "checkmark", color: Color(nsColor: .systemGreen))
        }
    }

    private func badgeCircle(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: Circle())
            .overlay(Circle().stroke(Color.black.opacity(0.72), lineWidth: 3))
    }
}
