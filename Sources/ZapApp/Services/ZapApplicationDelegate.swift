import AppKit

extension Notification.Name {
    static let zapApplicationShouldOpenSettings = Notification.Name("zapApplicationShouldOpenSettings")
}

final class ZapApplicationDelegate: NSObject, NSApplicationDelegate {
    var openSettings: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .zapApplicationShouldOpenSettings, object: nil)
        openSettings?()
        return false
    }
}
