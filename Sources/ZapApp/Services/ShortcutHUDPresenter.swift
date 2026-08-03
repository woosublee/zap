import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ZapCore

@MainActor
protocol ShortcutHUDScheduling: AnyObject {
    func schedule(
        after interval: TimeInterval,
        action: @escaping @MainActor () -> Void
    )
    func cancel()
}

@MainActor
final class TimerShortcutHUDScheduler: ShortcutHUDScheduling {
    private var timer: Timer?
    private let makeTimer: (
        TimeInterval,
        @escaping @Sendable (Timer) -> Void
    ) -> Timer
    private let addTimer: (Timer) -> Void

    init(
        makeTimer: @escaping (
            TimeInterval,
            @escaping @Sendable (Timer) -> Void
        ) -> Timer = {
            Timer(timeInterval: $0, repeats: false, block: $1)
        },
        addTimer: @escaping (Timer) -> Void = {
            RunLoop.main.add($0, forMode: .common)
        }
    ) {
        self.makeTimer = makeTimer
        self.addTimer = addTimer
    }

    func schedule(
        after interval: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) {
        cancel()
        guard interval > 0 else {
            action()
            return
        }
        let timer = makeTimer(interval) { [weak self] firedTimer in
            Task { @MainActor [weak self, weak firedTimer] in
                guard let self,
                      let firedTimer,
                      self.timer === firedTimer else {
                    return
                }
                self.timer = nil
                action()
            }
        }
        self.timer = timer
        addTimer(timer)
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}

@MainActor
protocol ShortcutHUDIconResolving {
    func icon(for payload: ShortcutHUDPayload) -> NSImage
}

@MainActor
struct WorkspaceShortcutHUDIconResolver: ShortcutHUDIconResolving {
    private let iconForURL: (URL) -> NSImage?
    private let applicationURL: (String) -> URL?
    private let defaultIcon: () -> NSImage
    private let iconForBundleURL: (URL) -> NSImage?

    init(
        iconForURL: @escaping (URL) -> NSImage? = {
            FileManager.default.fileExists(atPath: $0.path)
                ? NSWorkspace.shared.icon(forFile: $0.path)
                : nil
        },
        applicationURL: @escaping (String) -> URL? = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        },
        defaultIcon: @escaping () -> NSImage = {
            NSWorkspace.shared.icon(for: .application)
        },
        iconForBundleURL: @escaping (URL) -> NSImage? = {
            NSWorkspace.shared.icon(forFile: $0.path)
        }
    ) {
        self.iconForURL = iconForURL
        self.applicationURL = applicationURL
        self.defaultIcon = defaultIcon
        self.iconForBundleURL = iconForBundleURL
    }

    func icon(for payload: ShortcutHUDPayload) -> NSImage {
        if let url = payload.applicationURL,
           let icon = iconForURL(url) {
            return icon
        }
        if let bundleIdentifier = payload.bundleIdentifier,
           let url = applicationURL(bundleIdentifier),
           let icon = iconForBundleURL(url) {
            return icon
        }
        return defaultIcon()
    }
}

@MainActor
protocol ShortcutHUDAnnouncing {
    func announce(_ message: String) throws
}

@MainActor
struct SystemShortcutHUDAnnouncer: ShortcutHUDAnnouncing {
    func announce(_ message: String) throws {
        guard let application = NSApp else { return }
        NSAccessibility.post(
            element: application,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }
}

@MainActor
class ShortcutHUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class ShortcutHUDViewModel: ObservableObject {
    @Published var icon: NSImage?
    @Published var presentation: ShortcutHUDPresentation?
    @Published var opacity: Double = 0
    @Published var scale: CGFloat = 1
}

@MainActor
final class ShortcutHUDPresenter: ShortcutHUDPresenting {
    enum Phase: Equatable {
        case hidden
        case appearing
        case visible
        case fadingOut
    }

    private(set) var phase: Phase = .hidden
    private(set) var panel: ShortcutHUDPanel
    private(set) var viewModel = ShortcutHUDViewModel()
    private let iconResolver: any ShortcutHUDIconResolving
    private let announcer: any ShortcutHUDAnnouncing
    private let fadeScheduler: any ShortcutHUDScheduling
    private let hideScheduler: any ShortcutHUDScheduling
    private let announcementScheduler: any ShortcutHUDScheduling
    private let orderFront: @MainActor (ShortcutHUDPanel) throws -> Void
    private let reduceMotion: () -> Bool
    private let reduceTransparency: () -> Bool
    private var generation = 0

    init(
        panel: ShortcutHUDPanel? = nil,
        iconResolver: (any ShortcutHUDIconResolving)? = nil,
        announcer: (any ShortcutHUDAnnouncing)? = nil,
        fadeScheduler: (any ShortcutHUDScheduling)? = nil,
        hideScheduler: (any ShortcutHUDScheduling)? = nil,
        announcementScheduler: (any ShortcutHUDScheduling)? = nil,
        orderFront: @escaping @MainActor (ShortcutHUDPanel) throws -> Void = {
            $0.orderFrontRegardless()
        },
        reduceMotion: @escaping () -> Bool = {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        },
        reduceTransparency: @escaping () -> Bool = {
            NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        }
    ) {
        self.iconResolver = iconResolver ?? WorkspaceShortcutHUDIconResolver()
        self.announcer = announcer ?? SystemShortcutHUDAnnouncer()
        self.fadeScheduler = fadeScheduler ?? TimerShortcutHUDScheduler()
        self.hideScheduler = hideScheduler ?? TimerShortcutHUDScheduler()
        self.announcementScheduler = announcementScheduler ?? TimerShortcutHUDScheduler()
        self.orderFront = orderFront
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency

        self.panel = panel ?? Self.makePanel()
    }

    static func makePanel() -> ShortcutHUDPanel {
        let panel = ShortcutHUDPanel(
            contentRect: CGRect(origin: .zero, size: ShortcutHUDLayout.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        return panel
    }

    func present(_ payload: ShortcutHUDPayload, on display: DisplayFrame?) {
        generation += 1
        let requestGeneration = generation
        fadeScheduler.cancel()
        hideScheduler.cancel()
        announcementScheduler.cancel()

        let presentation = ShortcutHUDPresentation(
            payload: payload,
            reduceMotion: reduceMotion(),
            reduceTransparency: reduceTransparency()
        )
        viewModel.icon = iconResolver.icon(for: payload)
        viewModel.presentation = presentation

        if let display {
            installContentViewIfNeeded()
            panel.setFrame(ShortcutHUDLayout.panelFrame(on: display), display: false)
            do {
                try showOrRefreshPanel(presentation: presentation)
                scheduleFadeAndHide(generation: requestGeneration)
            } catch {
                panel.orderOut(nil)
                phase = .hidden
            }
        } else {
            panel.orderOut(nil)
            phase = .hidden
        }

        announcementScheduler.schedule(after: 0.10) { [weak self] in
            guard let self, requestGeneration == self.generation else { return }
            if self.phase == .appearing {
                self.phase = .visible
            }
            try? self.announcer.announce(presentation.announcement)
        }
    }

    private func installContentViewIfNeeded() {
        guard panel.contentViewController == nil else { return }
        panel.contentViewController = NSHostingController(
            rootView: ShortcutHUDView(model: viewModel)
        )
        panel.setContentSize(ShortcutHUDLayout.panelSize)
    }

    private func showOrRefreshPanel(
        presentation: ShortcutHUDPresentation
    ) throws {
        switch phase {
        case .hidden:
            viewModel.opacity = 0
            viewModel.scale = presentation.usesScaleAnimation ? 0.96 : 1
            try orderFront(panel)
            phase = .appearing
            withAnimation(.easeOut(duration: 0.10)) {
                viewModel.opacity = 1
                viewModel.scale = 1
            }
        case .appearing, .visible:
            break
        case .fadingOut:
            withAnimation(nil) {
                viewModel.opacity = 1
                viewModel.scale = 1
            }
            phase = .visible
        }
    }

    private func scheduleFadeAndHide(generation requestGeneration: Int) {
        fadeScheduler.schedule(after: 0.65) { [weak self] in
            guard let self, requestGeneration == self.generation else { return }
            self.phase = .fadingOut
            withAnimation(.easeIn(duration: 0.15)) {
                self.viewModel.opacity = 0
            }
        }
        hideScheduler.schedule(after: 0.80) { [weak self] in
            guard let self, requestGeneration == self.generation else { return }
            self.panel.orderOut(nil)
            self.phase = .hidden
        }
    }
}
