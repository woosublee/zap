import CoreGraphics
import SwiftUI

enum AboutLayout {
    static let contentWidth: CGFloat = 292
    static let windowHeight: CGFloat = 260
}

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
        .frame(width: AboutLayout.contentWidth)
    }
}
