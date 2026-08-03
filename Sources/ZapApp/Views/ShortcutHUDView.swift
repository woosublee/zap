import AppKit
import SwiftUI

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
            RoundedRectangle(
                cornerRadius: ShortcutHUDLayout.cornerRadius,
                style: .continuous
            )
            .fill(
                presentation.usesOpaqueBackground
                    ? AnyShapeStyle(Color.black.opacity(0.90))
                    : AnyShapeStyle(.ultraThinMaterial)
            )

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
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
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
