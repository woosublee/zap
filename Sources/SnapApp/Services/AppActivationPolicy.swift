import AppKit

@MainActor
enum AppActivationPolicy {
    static func apply(showMenuBarIcon: Bool) {
        let app = NSApplication.shared
        app.setActivationPolicy(showMenuBarIcon ? .accessory : .regular)
        if !showMenuBarIcon {
            app.activate(ignoringOtherApps: true)
        }
    }
}
