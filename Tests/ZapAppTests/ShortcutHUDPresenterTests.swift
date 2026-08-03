import AppKit
import XCTest
@testable import ZapApp
@testable import ZapCore

@MainActor
final class ShortcutHUDPresenterTests: XCTestCase {
    func testTimerSchedulerIgnoresStaleCallbackAfterReplacement() async {
        var callbacks: [@Sendable (Timer) -> Void] = []
        var timers: [Timer] = []
        let scheduler = TimerShortcutHUDScheduler(
            makeTimer: { interval, callback in
                let timer = Timer(
                    timeInterval: interval,
                    repeats: false,
                    block: { _ in }
                )
                callbacks.append(callback)
                timers.append(timer)
                return timer
            },
            addTimer: { _ in }
        )
        var actions: [String] = []

        scheduler.schedule(after: 1) { actions.append("first") }
        callbacks[0](timers[0])
        scheduler.schedule(after: 1) { actions.append("second") }
        await Task.yield()

        XCTAssertTrue(actions.isEmpty)

        scheduler.cancel()
        callbacks[1](timers[1])
        await Task.yield()

        XCTAssertTrue(actions.isEmpty)
    }

    func testPanelUsesNonActivatingFullScreenAuxiliaryContract() {
        let presenter = makePresenter()
        let panel = presenter.panel

        XCTAssertTrue(panel.styleMask.contains(.borderless))
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertEqual(panel.level, .floating)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.transient))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.hidesOnDeactivate)
        XCTAssertFalse(panel.isReleasedWhenClosed)
    }

    func testIconResolverUsesURLThenBundleIdentifierThenDefault() {
        let urlIcon = NSImage(size: NSSize(width: 16, height: 16))
        let bundleIcon = NSImage(size: NSSize(width: 17, height: 17))
        let defaultIcon = NSImage(size: NSSize(width: 18, height: 18))
        let bundleURL = URL(fileURLWithPath: "/Applications/Bundle.app")
        let resolver = WorkspaceShortcutHUDIconResolver(
            iconForURL: { url in url.path.contains("Direct") ? urlIcon : nil },
            applicationURL: { _ in bundleURL },
            defaultIcon: { defaultIcon },
            iconForBundleURL: { _ in bundleIcon }
        )

        let direct = ShortcutHUDPayload(
            action: .appActivated,
            appName: "Direct",
            bundleIdentifier: "com.example.Direct",
            applicationURL: URL(fileURLWithPath: "/Applications/Direct.app")
        )
        let bundle = ShortcutHUDPayload(
            action: .appActivated,
            appName: "Bundle",
            bundleIdentifier: "com.example.Bundle",
            applicationURL: nil
        )
        let fallback = ShortcutHUDPayload(
            action: .appActivated,
            appName: "Fallback",
            bundleIdentifier: nil,
            applicationURL: nil
        )

        XCTAssertTrue(resolver.icon(for: direct) === urlIcon)
        XCTAssertTrue(resolver.icon(for: bundle) === bundleIcon)
        XCTAssertTrue(resolver.icon(for: fallback) === defaultIcon)
    }

    func testPresenterSchedulesAnnouncementFadeAndHideFromLatestRequest() {
        let fade = CapturingShortcutHUDScheduler()
        let hide = CapturingShortcutHUDScheduler()
        let announcement = CapturingShortcutHUDScheduler()
        let announcer = CapturingShortcutHUDAnnouncer()
        let presenter = makePresenter(
            fadeScheduler: fade,
            hideScheduler: hide,
            announcementScheduler: announcement,
            announcer: announcer
        )
        let display = DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 775),
            isMain: true
        )

        presenter.present(payload(action: .appActivated, name: "Safari"), on: display)

        XCTAssertEqual(announcement.scheduledIntervals, [0.10])
        XCTAssertEqual(
            fade.scheduledIntervals,
            [ShortcutHUDTiming.fadeDelay(usesScaleAnimation: true)]
        )
        XCTAssertEqual(
            hide.scheduledIntervals,
            [ShortcutHUDTiming.hideDelay(usesScaleAnimation: true)]
        )
        XCTAssertEqual(presenter.phase, .visible)
        XCTAssertEqual(presenter.panel.frame.midX, display.frame.midX, accuracy: 0.001)
        XCTAssertEqual(presenter.panel.frame.midY, display.frame.midY, accuracy: 0.001)

        announcement.fireLatest()
        XCTAssertEqual(announcer.messages, ["Safari activated"])
        XCTAssertEqual(presenter.phase, .visible)
        fade.fireLatest()
        XCTAssertEqual(presenter.phase, .fadingOut)
        XCTAssertEqual(presenter.viewModel.opacity, 0)
        XCTAssertEqual(presenter.viewModel.scale, 1)
        hide.fireLatest()
        XCTAssertEqual(presenter.phase, .hidden)
        XCTAssertFalse(presenter.panel.isVisible)
    }

    func testMotionTimingDefinesCReboundAndDerivedSpringLifecycle() {
        XCTAssertEqual(ShortcutHUDTiming.initialScale, 0.82)
        XCTAssertEqual(ShortcutHUDTiming.springResponse, 0.24)
        XCTAssertEqual(ShortcutHUDTiming.springDampingFraction, 0.62)
        XCTAssertEqual(ShortcutHUDTiming.springSettlingDuration, 0.36)
        XCTAssertEqual(ShortcutHUDTiming.stableHoldDuration, 0.30)
        XCTAssertEqual(ShortcutHUDTiming.fadeOutDuration, 0.09)

        let expectedFadeDelay = ShortcutHUDTiming.springSettlingDuration
            + ShortcutHUDTiming.stableHoldDuration
        XCTAssertEqual(expectedFadeDelay, 0.66, accuracy: 0.000_001)
        XCTAssertEqual(
            expectedFadeDelay + ShortcutHUDTiming.fadeOutDuration,
            0.75,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            ShortcutHUDTiming.fadeDelay(usesScaleAnimation: true),
            expectedFadeDelay
        )
        XCTAssertEqual(
            ShortcutHUDTiming.hideDelay(usesScaleAnimation: true),
            expectedFadeDelay + ShortcutHUDTiming.fadeOutDuration
        )
    }

    func testReducedMotionUsesOpacityEntryBeforeStableHold() {
        let fade = CapturingShortcutHUDScheduler()
        let hide = CapturingShortcutHUDScheduler()
        let presenter = makePresenter(
            fadeScheduler: fade,
            hideScheduler: hide,
            reduceMotion: { true }
        )
        let display = DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 775),
            isMain: true
        )

        presenter.present(payload(action: .appActivated, name: "Safari"), on: display)

        let expectedFadeDelay = ShortcutHUDTiming.opacityEntryDuration
            + ShortcutHUDTiming.stableHoldDuration
        XCTAssertEqual(expectedFadeDelay, 0.40)
        XCTAssertEqual(expectedFadeDelay + ShortcutHUDTiming.fadeOutDuration, 0.49)
        XCTAssertEqual(fade.scheduledIntervals, [expectedFadeDelay])
        XCTAssertEqual(
            hide.scheduledIntervals,
            [expectedFadeDelay + ShortcutHUDTiming.fadeOutDuration]
        )
        XCTAssertEqual(presenter.viewModel.scale, 1)
    }

    func testPresenterStagesInitialSpringBeforeSchedulingVisualLifecycle() {
        let entry = CapturingShortcutHUDEntryEnqueuer()
        let fade = CapturingShortcutHUDScheduler()
        let hide = CapturingShortcutHUDScheduler()
        let display = DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 775),
            isMain: true
        )
        let presenter = makePresenter(
            fadeScheduler: fade,
            hideScheduler: hide,
            entryEnqueuer: entry
        )

        presenter.present(payload(action: .appActivated, name: "Safari"), on: display)

        XCTAssertEqual(presenter.phase, .visible)
        XCTAssertEqual(presenter.viewModel.opacity, 0)
        XCTAssertEqual(presenter.viewModel.scale, ShortcutHUDTiming.initialScale)
        XCTAssertEqual(entry.enqueuedActionCount, 1)
        XCTAssertTrue(fade.scheduledIntervals.isEmpty)
        XCTAssertTrue(hide.scheduledIntervals.isEmpty)

        entry.fireLatest()

        XCTAssertEqual(presenter.viewModel.opacity, 1)
        XCTAssertEqual(presenter.viewModel.scale, 1)
        XCTAssertEqual(
            fade.scheduledIntervals,
            [ShortcutHUDTiming.fadeDelay(usesScaleAnimation: true)]
        )
        XCTAssertEqual(
            hide.scheduledIntervals,
            [ShortcutHUDTiming.hideDelay(usesScaleAnimation: true)]
        )
    }

    func testVisibleRefreshUpdatesPayloadWithoutExtendingVisualLifecycle() {
        let fade = CapturingShortcutHUDScheduler()
        let hide = CapturingShortcutHUDScheduler()
        let presenter = makePresenter(
            fadeScheduler: fade,
            hideScheduler: hide
        )
        let display = DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 775),
            isMain: true
        )

        presenter.present(payload(action: .appActivated, name: "Safari"), on: display)
        presenter.present(payload(action: .appHotKeysDisabled, name: "Notes"), on: display)

        XCTAssertEqual(fade.scheduledIntervals.count, 1)
        XCTAssertEqual(hide.scheduledIntervals.count, 1)

        fade.fire(at: 0)
        XCTAssertEqual(presenter.phase, .fadingOut)
        hide.fire(at: 0)
        XCTAssertEqual(presenter.phase, .hidden)
    }

    func testFadeRecoveryStartsNewLifecycleWithoutRestartingSpring() {
        let entry = CapturingShortcutHUDEntryEnqueuer()
        let fade = CapturingShortcutHUDScheduler()
        let hide = CapturingShortcutHUDScheduler()
        let presenter = makePresenter(
            fadeScheduler: fade,
            hideScheduler: hide,
            entryEnqueuer: entry
        )
        let display = DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 775),
            isMain: true
        )

        presenter.present(payload(action: .appActivated, name: "Safari"), on: display)
        entry.fireLatest()
        fade.fireLatest()
        presenter.present(payload(action: .appHotKeysDisabled, name: "Notes"), on: display)

        XCTAssertEqual(entry.enqueuedActionCount, 1)
        XCTAssertEqual(presenter.phase, .visible)
        XCTAssertEqual(presenter.viewModel.opacity, 1)
        XCTAssertEqual(presenter.viewModel.scale, 1)
        XCTAssertEqual(fade.scheduledIntervals.count, 2)
        XCTAssertEqual(hide.scheduledIntervals.count, 2)

        hide.fire(at: 0)
        XCTAssertEqual(presenter.phase, .visible)
    }

    func testRapidReplacementAnnouncesOnlyLatestPayload() {
        let announcement = CapturingShortcutHUDScheduler()
        let announcer = CapturingShortcutHUDAnnouncer()
        let presenter = makePresenter(
            announcementScheduler: announcement,
            announcer: announcer
        )

        presenter.present(payload(action: .appActivated, name: "Safari"), on: nil)
        presenter.present(payload(action: .appHotKeysDisabled, name: "Notes"), on: nil)
        announcement.fireLatest()

        XCTAssertEqual(announcer.messages, ["Zap shortcuts disabled in Notes"])
        XCTAssertFalse(presenter.panel.isVisible)
    }

    func testStaleAnnouncementIsIgnoredWhileLeadingVisualLifecycleRemainsValid() {
        let fade = CapturingShortcutHUDScheduler()
        let hide = CapturingShortcutHUDScheduler()
        let announcement = CapturingShortcutHUDScheduler()
        let announcer = CapturingShortcutHUDAnnouncer()
        let presenter = makePresenter(
            fadeScheduler: fade,
            hideScheduler: hide,
            announcementScheduler: announcement,
            announcer: announcer
        )
        let display = DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 775),
            isMain: true
        )

        presenter.present(payload(action: .appActivated, name: "Safari"), on: display)
        presenter.present(payload(action: .appHotKeysEnabled, name: "Notes"), on: display)
        announcement.fire(at: 0)
        fade.fire(at: 0)
        hide.fire(at: 0)

        XCTAssertTrue(announcer.messages.isEmpty)
        XCTAssertEqual(presenter.phase, .hidden)
        XCTAssertFalse(presenter.panel.isVisible)

        announcement.fire(at: 1)
        XCTAssertEqual(announcer.messages, ["Zap shortcuts enabled in Notes"])
    }

    func testRequestDuringFadeOutRestoresFullOpacityWithoutReplacingPanel() {
        let fade = CapturingShortcutHUDScheduler()
        let presenter = makePresenter(fadeScheduler: fade)
        let display = DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 775),
            isMain: true
        )
        let panelIdentifier = ObjectIdentifier(presenter.panel)

        presenter.present(payload(action: .appActivated, name: "Safari"), on: display)
        fade.fireLatest()
        XCTAssertEqual(presenter.phase, .fadingOut)

        presenter.present(payload(action: .appHotKeysDisabled, name: "Notes"), on: display)

        XCTAssertEqual(ObjectIdentifier(presenter.panel), panelIdentifier)
        XCTAssertEqual(presenter.phase, .visible)
        XCTAssertEqual(presenter.viewModel.opacity, 1)
        XCTAssertEqual(presenter.viewModel.scale, 1)
    }

    func testNilDisplaySkipsPanelButStillAnnounces() {
        let announcement = CapturingShortcutHUDScheduler()
        let announcer = CapturingShortcutHUDAnnouncer()
        let presenter = makePresenter(
            announcementScheduler: announcement,
            announcer: announcer
        )

        presenter.present(payload(action: .appActivated, name: "Safari"), on: nil)
        announcement.fireLatest()

        XCTAssertFalse(presenter.panel.isVisible)
        XCTAssertEqual(announcer.messages, ["Safari activated"])
    }

    func testPanelOrderingFailureStillAnnouncesSuccessfulAction() {
        let announcement = CapturingShortcutHUDScheduler()
        let announcer = CapturingShortcutHUDAnnouncer()
        let presenter = makePresenter(
            announcementScheduler: announcement,
            announcer: announcer,
            orderFront: { _ in throw TestPanelOrderError() }
        )
        let display = DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 775),
            isMain: true
        )

        presenter.present(payload(action: .appActivated, name: "Safari"), on: display)
        announcement.fireLatest()

        XCTAssertFalse(presenter.panel.isVisible)
        XCTAssertEqual(presenter.phase, .hidden)
        XCTAssertEqual(announcer.messages, ["Safari activated"])
    }

    func testAnnouncementFailureDoesNotHideVisualHUD() {
        let announcement = CapturingShortcutHUDScheduler()
        let presenter = makePresenter(
            announcementScheduler: announcement,
            announcer: ThrowingShortcutHUDAnnouncer()
        )
        let display = DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 775),
            isMain: true
        )

        presenter.present(payload(action: .appActivated, name: "Safari"), on: display)
        announcement.fireLatest()

        XCTAssertTrue(presenter.panel.isVisible)
        XCTAssertEqual(presenter.phase, .visible)
    }

    func testPresenterDefersHostingViewInstallationUntilFirstVisualPresentation() {
        let presenter = makePresenter()
        let display = DisplayFrame(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 775),
            isMain: true
        )

        XCTAssertNil(presenter.panel.contentViewController)

        presenter.present(payload(action: .appActivated, name: "Safari"), on: display)

        XCTAssertNotNil(presenter.panel.contentViewController)
        XCTAssertEqual(presenter.panel.frame.size, ShortcutHUDLayout.panelSize)
    }

    func testPanelFrameIncludesMotionInsetAroundCenteredCard() {
        let presenter = makePresenter()

        XCTAssertEqual(presenter.panel.frame.size, ShortcutHUDLayout.panelSize)
        XCTAssertEqual(
            presenter.panel.frame.width,
            ShortcutHUDLayout.cardSize.width + ShortcutHUDLayout.motionInset * 2
        )
        XCTAssertEqual(
            presenter.panel.frame.height,
            ShortcutHUDLayout.cardSize.height + ShortcutHUDLayout.motionInset * 2
        )
        XCTAssertFalse(presenter.panel.hasShadow)
    }

    func testMaterialViewUsesNativeHUDWindowConfigurationAndCornerClipping() {
        let materialView = ShortcutHUDMaterialView(frame: .zero)

        XCTAssertEqual(materialView.material, .hudWindow)
        XCTAssertEqual(materialView.blendingMode, .behindWindow)
        XCTAssertEqual(materialView.state, .active)
        XCTAssertEqual(materialView.alphaValue, 0.72)
        XCTAssertFalse(materialView.isEmphasized)
        XCTAssertTrue(materialView.wantsLayer)
        XCTAssertEqual(
            materialView.layer?.cornerRadius,
            ShortcutHUDLayout.cornerRadius
        )
        XCTAssertEqual(materialView.layer?.cornerCurve, .continuous)
        XCTAssertTrue(materialView.layer?.masksToBounds == true)
    }

    func testPresenterPassesReduceMotionAndTransparencyIntoPresentation() {
        let presenter = makePresenter(
            reduceMotion: { true },
            reduceTransparency: { true }
        )

        presenter.present(payload(action: .appActivated, name: "Safari"), on: nil)

        XCTAssertFalse(presenter.viewModel.presentation?.usesScaleAnimation == true)
        XCTAssertTrue(presenter.viewModel.presentation?.usesOpaqueBackground == true)
    }

    private func makePresenter(
        fadeScheduler: CapturingShortcutHUDScheduler? = nil,
        hideScheduler: CapturingShortcutHUDScheduler? = nil,
        announcementScheduler: CapturingShortcutHUDScheduler? = nil,
        entryEnqueuer: (any ShortcutHUDEntryEnqueuing)? = nil,
        announcer: (any ShortcutHUDAnnouncing)? = nil,
        orderFront: @escaping @MainActor (ShortcutHUDPanel) throws -> Void = {
            $0.orderFrontRegardless()
        },
        reduceMotion: @escaping () -> Bool = { false },
        reduceTransparency: @escaping () -> Bool = { false }
    ) -> ShortcutHUDPresenter {
        ShortcutHUDPresenter(
            iconResolver: StubShortcutHUDIconResolver(),
            announcer: announcer ?? CapturingShortcutHUDAnnouncer(),
            fadeScheduler: fadeScheduler ?? CapturingShortcutHUDScheduler(),
            hideScheduler: hideScheduler ?? CapturingShortcutHUDScheduler(),
            announcementScheduler: announcementScheduler ?? CapturingShortcutHUDScheduler(),
            entryEnqueuer: entryEnqueuer ?? ImmediateShortcutHUDEntryEnqueuer(),
            orderFront: orderFront,
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency
        )
    }

    private func payload(
        action: ShortcutHUDAction,
        name: String
    ) -> ShortcutHUDPayload {
        ShortcutHUDPayload(
            action: action,
            appName: name,
            bundleIdentifier: "com.example.\(name)",
            applicationURL: nil
        )
    }
}

@MainActor
private final class ImmediateShortcutHUDEntryEnqueuer: ShortcutHUDEntryEnqueuing {
    func enqueue(action: @escaping @MainActor () -> Void) {
        action()
    }
}

@MainActor
private final class CapturingShortcutHUDEntryEnqueuer: ShortcutHUDEntryEnqueuing {
    private var actions: [@MainActor () -> Void] = []

    var enqueuedActionCount: Int {
        actions.count
    }

    func enqueue(action: @escaping @MainActor () -> Void) {
        actions.append(action)
    }

    func fireLatest() {
        actions.last?()
    }
}

@MainActor
private final class CapturingShortcutHUDScheduler: ShortcutHUDScheduling {
    private(set) var scheduledIntervals: [TimeInterval] = []
    private(set) var scheduledActions: [@MainActor () -> Void] = []
    private var currentActionIndex: Int?

    func schedule(
        after interval: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) {
        scheduledIntervals.append(interval)
        scheduledActions.append(action)
        currentActionIndex = scheduledActions.indices.last
    }

    func cancel() {
        currentActionIndex = nil
    }

    func fireLatest() {
        guard let currentActionIndex else { return }
        self.currentActionIndex = nil
        scheduledActions[currentActionIndex]()
    }

    func fire(at index: Int) {
        scheduledActions[index]()
    }
}

@MainActor
private final class CapturingShortcutHUDAnnouncer: ShortcutHUDAnnouncing {
    private(set) var messages: [String] = []

    func announce(_ message: String) throws {
        messages.append(message)
    }
}

@MainActor
private struct ThrowingShortcutHUDAnnouncer: ShortcutHUDAnnouncing {
    struct AnnouncementError: Error {}

    func announce(_ message: String) throws {
        throw AnnouncementError()
    }
}

@MainActor
private struct StubShortcutHUDIconResolver: ShortcutHUDIconResolving {
    let image = NSImage(size: NSSize(width: 32, height: 32))

    func icon(for payload: ShortcutHUDPayload) -> NSImage {
        image
    }
}

private struct TestPanelOrderError: Error {}
