import AppKit

extension Notification.Name {
    static let zapApplicationShouldOpenSettings = Notification.Name("zapApplicationShouldOpenSettings")
}

final class ZapApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .zapApplicationShouldOpenSettings, object: nil)
        return false
    }
}
