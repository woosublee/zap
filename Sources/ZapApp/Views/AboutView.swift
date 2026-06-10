import SwiftUI

struct AboutView: View {
    let presentation: AboutPresentation

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(presentation.appName)
                    .font(.system(size: 21, weight: .semibold))

                Text(presentation.versionLine)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Link(presentation.creatorLine, destination: presentation.creatorURL)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tint)
        }
        .padding(28)
        .frame(width: 292)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}
