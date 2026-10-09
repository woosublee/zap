import SwiftUI

struct ZapSpacing {
    static let small: CGFloat = 6
    static let medium: CGFloat = 10
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 22
}

struct SettingsCard<Accessory: View, Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let accessory: Accessory
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.medium) {
            HStack(alignment: .center, spacing: ZapSpacing.medium) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.headline, design: .default, weight: .semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: ZapSpacing.medium)

                accessory
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

extension SettingsCard where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, content: content, accessory: { EmptyView() })
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

enum ShortcutKeycapLabel {
    static func display(_ label: String) -> String {
        switch label {
        case "Return": "↩"
        case "Tab": "⇥"
        case "Delete": "⌫"
        case "Esc": "⎋"
        default: label
        }
    }
}

struct ShortcutKeycapView: View {
    let label: String
    var isSelected = false
    var isDisabled = false

    var body: some View {
        Text(displayLabel)
            .lineLimit(1)
            .fixedSize()
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundStyle)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, displayLabel.count > 1 ? 7 : 0)
            .background(backgroundShape)
            .overlay(borderShape)
            .opacity(isDisabled ? 0.55 : 1)
            .accessibilityLabel(label)
    }

    private var displayLabel: String {
        ShortcutKeycapLabel.display(label)
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
                ShortcutKeycapView(label: token, isDisabled: isDisabled || isShortcutUnset)
            }
        }
        .accessibilityLabel(isShortcutUnset ? "Shortcut not set" : shortcut ?? "Shortcut not set")
    }

    private var isShortcutUnset: Bool {
        shortcut?.isEmpty ?? true
    }

    private var tokens: [String] {
        guard let shortcut, !isShortcutUnset else { return ["Not set"] }

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

struct SettingsIssueBanner: View {
    let messages: [String]

    init(messages: [String?]) {
        self.messages = Self.uniqueMessages(messages)
    }

    static func uniqueMessages(_ messages: [String?]) -> [String] {
        var seen = Set<String>()
        return messages
            .compactMap { $0 }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    var body: some View {
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(messages, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
            )
        }
    }
}
