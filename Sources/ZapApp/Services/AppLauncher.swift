import AppKit

protocol AppLaunching {
    func activateOrLaunch(_ item: DockItem)
    func activateFinder()
}

struct AppLauncher: AppLaunching {
    private let runningApplication: (String) -> NSRunningApplication?
    private let activateRunningApplication: (NSRunningApplication, NSApplication.ActivationOptions) -> Void
    private let applicationURL: (String) -> URL?
    private let openApplication: (URL, NSWorkspace.OpenConfiguration, @escaping (NSRunningApplication?, Error?) -> Void) -> Void
    private let beep: () -> Void
    private let sendReopenEventHandler: (NSRunningApplication) -> Void

    init(
        runningApplication: @escaping (String) -> NSRunningApplication? = { NSRunningApplication.runningApplications(withBundleIdentifier: $0).first },
        activateRunningApplication: @escaping (NSRunningApplication, NSApplication.ActivationOptions) -> Void = { app, options in
            app.activate(options: options)
        },
        applicationURL: @escaping (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) },
        openApplication: @escaping (URL, NSWorkspace.OpenConfiguration, @escaping (NSRunningApplication?, Error?) -> Void) -> Void = { url, configuration, completion in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: completion)
        },
        beep: @escaping () -> Void = { NSSound.beep() },
        sendReopenEvent: ((NSRunningApplication) -> Void)? = nil
    ) {
        self.runningApplication = runningApplication
        self.activateRunningApplication = activateRunningApplication
        self.applicationURL = applicationURL
        self.openApplication = openApplication
        self.beep = beep
        self.sendReopenEventHandler = sendReopenEvent ?? Self.sendReopenEvent(to:)
    }

    func activateOrLaunch(_ item: DockItem) {
        if let bundleIdentifier = item.bundleIdentifier,
           let runningApp = runningApplication(bundleIdentifier) {
            activateRunningApplication(runningApp, [.activateIgnoringOtherApps])
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        openApplication(item.url, configuration) { _, error in
            if error != nil {
                beep()
            }
        }
    }

    func activateFinder() {
        let bundleIdentifier = "com.apple.finder"
        if let runningApp = runningApplication(bundleIdentifier) {
            activateRunningApplication(runningApp, [.activateAllWindows, .activateIgnoringOtherApps])
            sendReopenEventHandler(runningApp)
            return
        }

        guard let url = applicationURL(bundleIdentifier) else {
            beep()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        openApplication(url, configuration) { _, error in
            if error != nil {
                beep()
            }
        }
    }

    private static func sendReopenEvent(to app: NSRunningApplication) {
        let target = NSAppleEventDescriptor(processIdentifier: app.processIdentifier)
        let event = NSAppleEventDescriptor.appleEvent(
            withEventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEReopenApplication),
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        _ = try? event.sendEvent(options: [.noReply], timeout: 1)
    }
}
