import AppKit

extension Notification.Name {
    static let zapApplicationShouldOpenSettings = Notification.Name("zapApplicationShouldOpenSettings")
}

final class ZapApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = BuildFlavorIcons.appIcon(base: NSApplication.shared.applicationIconImage, flavor: AppBuildFlavor.current) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .zapApplicationShouldOpenSettings, object: nil)
        return false
    }
}
