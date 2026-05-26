import SwiftUI

struct AboutView: View {
    let presentation: AboutPresentation

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            Text(presentation.appName)
                .font(.system(size: 20, weight: .semibold))

            Text(presentation.versionLine)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Link(presentation.creatorLine, destination: presentation.creatorURL)
                .font(.system(size: 12))
        }
        .padding(28)
        .frame(width: 280)
    }
}
