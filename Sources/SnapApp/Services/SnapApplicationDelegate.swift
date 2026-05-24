import AppKit

extension Notification.Name {
    static let snapApplicationShouldOpenSettings = Notification.Name("snapApplicationShouldOpenSettings")
}

final class SnapApplicationDelegate: NSObject, NSApplicationDelegate {
    var openSettings: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .snapApplicationShouldOpenSettings, object: nil)
        openSettings?()
        return false
    }
}
