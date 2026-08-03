import AppKit

enum AppLaunchOutcome: Equatable {
    case activated
    case launched
    case failed
}

@MainActor
protocol AppLaunching {
    func activateOrLaunch(
        _ item: DockItem,
        completion: @escaping (AppLaunchOutcome) -> Void
    )
    func activateFinder(
        completion: @escaping (AppLaunchOutcome) -> Void
    )
}

@MainActor
struct AppLauncher: AppLaunching {
    private let runningApplication: (String) -> NSRunningApplication?
    private let activateRunningApplication: (
        NSRunningApplication,
        NSApplication.ActivationOptions
    ) -> Bool
    private let applicationURL: (String) -> URL?
    private let openApplication: (
        URL,
        NSWorkspace.OpenConfiguration,
        @escaping @Sendable (NSRunningApplication?, Error?) -> Void
    ) -> Void
    private let beep: () -> Void
    private let sendReopenEventHandler: (NSRunningApplication) -> Void

    init(
        runningApplication: @escaping (String) -> NSRunningApplication? = {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0).first
        },
        activateRunningApplication: @escaping (
            NSRunningApplication,
            NSApplication.ActivationOptions
        ) -> Bool = { app, options in
            app.activate(options: options)
        },
        applicationURL: @escaping (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        },
        openApplication: @escaping (
            URL,
            NSWorkspace.OpenConfiguration,
            @escaping @Sendable (NSRunningApplication?, Error?) -> Void
        ) -> Void = { url, configuration, completion in
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: configuration,
                completionHandler: completion
            )
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

    func activateOrLaunch(
        _ item: DockItem,
        completion: @escaping (AppLaunchOutcome) -> Void
    ) {
        var didComplete = false
        let finish: @MainActor (AppLaunchOutcome) -> Void = { outcome in
            guard !didComplete else { return }
            didComplete = true
            if outcome == .failed {
                beep()
            }
            completion(outcome)
        }

        if let bundleIdentifier = item.bundleIdentifier,
           let runningApp = runningApplication(bundleIdentifier) {
            let activated = activateRunningApplication(
                runningApp,
                [.activateIgnoringOtherApps]
            )
            finish(activated ? .activated : .failed)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        openApplication(item.url, configuration) { runningApp, error in
            Task { @MainActor in
                finish(error == nil && runningApp != nil ? .launched : .failed)
            }
        }
    }

    func activateFinder(
        completion: @escaping (AppLaunchOutcome) -> Void
    ) {
        var didComplete = false
        let finish: @MainActor (AppLaunchOutcome) -> Void = { outcome in
            guard !didComplete else { return }
            didComplete = true
            if outcome == .failed {
                beep()
            }
            completion(outcome)
        }

        let bundleIdentifier = "com.apple.finder"
        if let runningApp = runningApplication(bundleIdentifier) {
            let activated = activateRunningApplication(
                runningApp,
                [.activateAllWindows, .activateIgnoringOtherApps]
            )
            guard activated else {
                finish(.failed)
                return
            }
            sendReopenEventHandler(runningApp)
            finish(.activated)
            return
        }

        guard let url = applicationURL(bundleIdentifier) else {
            finish(.failed)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        openApplication(url, configuration) { runningApp, error in
            Task { @MainActor in
                finish(error == nil && runningApp != nil ? .launched : .failed)
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
