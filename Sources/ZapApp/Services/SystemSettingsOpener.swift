import AppKit

protocol SystemSettingsOpening {
    @discardableResult
    func openAccessibilitySettings() -> Bool
}

struct SystemSettingsOpener: SystemSettingsOpening {
    private let openURL: (URL) -> Bool

    init(openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }) {
        self.openURL = openURL
    }

    @discardableResult
    func openAccessibilitySettings() -> Bool {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return false
        }
        return openURL(url)
    }
}
