import SwiftUI

struct ZapSpacing {
    static let small: CGFloat = 6
    static let medium: CGFloat = 10
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 22
}

struct SettingsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.medium) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.headline, design: .default, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

struct SettingsRow<Leading: View, Trailing: View>: View {
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: ZapSpacing.medium) {
            leading

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: ZapSpacing.large)

            trailing
        }
        .padding(.vertical, 5)
    }
}

struct ShortcutKeycapView: View {
    let label: String
    var isSelected = false
    var isDisabled = false

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundStyle)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, label.count > 1 ? 7 : 0)
            .background(backgroundShape)
            .overlay(borderShape)
            .opacity(isDisabled ? 0.55 : 1)
            .accessibilityLabel(label)
    }

    private var foregroundStyle: Color {
        if isDisabled { return .secondary }
        return isSelected ? .accentColor : .primary
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
    }

    private var borderShape: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(isSelected ? Color.accentColor.opacity(0.75) : Color.primary.opacity(0.14), lineWidth: 0.75)
    }
}

struct ShortcutKeycapGroupView: View {
    let shortcut: String?
    var isDisabled = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tokens, id: \.self) { token in
                ShortcutKeycapView(label: token, isDisabled: isDisabled || shortcut == nil)
            }
        }
        .accessibilityLabel(shortcut ?? "Shortcut not set")
    }

    private var tokens: [String] {
        guard let shortcut, !shortcut.isEmpty else { return ["Not set"] }

        let modifiers = Set(["⌘", "⌃", "⌥", "⇧"])
        var output: [String] = []
        var buffer = ""

        for characterIndex in shortcut.indices {
            let character = shortcut[characterIndex]
            let token = String(character)
            if modifiers.contains(token) {
                if !buffer.isEmpty {
                    output.append(buffer)
                    buffer = ""
                }
                output.append(token)
            } else if token == "+", characterIndex == shortcut.indices.last {
                buffer.append(character)
            } else if token != " " && token != "+" {
                buffer.append(character)
            }
        }

        if !buffer.isEmpty {
            output.append(buffer)
        }

        return output.isEmpty ? [shortcut] : output
    }
}
