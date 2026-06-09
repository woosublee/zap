import Carbon
import XCTest
@testable import ZapApp
@testable import ZapCore

final class GlobalHotKeyDispatchMappingTests: XCTestCase {
    func testDispatchWindowHotKeyID2000InvokesFirstWindowActionCallback() {
        let expectation = expectation(description: "Window hotkey callback")
        var receivedActions: [WindowAction] = []
        let service = makeRegisteredService(
            windowShortcuts: [
                windowShortcut(.center, keyCode: 8, modifiers: [.option, .command]),
                windowShortcut(.fullscreen, keyCode: 3, modifiers: [.option, .command])
            ],
            onWindowHotKey: { action in
                receivedActions.append(action)
                expectation.fulfill()
            }
        )

        XCTAssertTrue(service.dispatchHotKey(id: 2000))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedActions, [.center])
    }

    func testDispatchWindowHotKeyID2001InvokesSecondWindowActionCallback() {
        let expectation = expectation(description: "Window hotkey callback")
        var receivedActions: [WindowAction] = []
        let service = makeRegisteredService(
            windowShortcuts: [
                windowShortcut(.center, keyCode: 8, modifiers: [.option, .command]),
                windowShortcut(.fullscreen, keyCode: 3, modifiers: [.control, .command])
            ],
            onWindowHotKey: { action in
                receivedActions.append(action)
                expectation.fulfill()
            }
        )

        XCTAssertTrue(service.dispatchHotKey(id: 2001))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedActions, [.fullscreen])
    }

    func testFinderIDsStillInvokeOnlyFinderCallback() {
        let expectation = expectation(description: "Finder hotkey callback")
        var finderCallCount = 0
        let service = makeRegisteredService(
            finderShortcutEnabled: true,
            onDockHotKey: { _ in XCTFail("Finder ID must not invoke Dock callback.") },
            onFinderHotKey: {
                finderCallCount += 1
                expectation.fulfill()
            },
            onManualHotKey: { _ in XCTFail("Finder ID must not invoke manual callback.") },
            onWindowHotKey: { _ in XCTFail("Finder ID must not invoke window callback.") }
        )

        XCTAssertTrue(service.dispatchHotKey(id: 100))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(finderCallCount, 1)
    }

    func testManualIDsStillInvokeOnlyManualCallbackWithStoredShortcutID() {
        let expectation = expectation(description: "Manual hotkey callback")
        let manualID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        var receivedIDs: [UUID] = []
        let service = makeRegisteredService(
            manualShortcuts: [manualShortcut(id: manualID, keyCode: 17, modifiers: [.control, .option])],
            onDockHotKey: { _ in XCTFail("Manual ID must not invoke Dock callback.") },
            onFinderHotKey: { XCTFail("Manual ID must not invoke Finder callback.") },
            onManualHotKey: { id in
                receivedIDs.append(id)
                expectation.fulfill()
            },
            onWindowHotKey: { _ in XCTFail("Manual ID must not invoke window callback.") }
        )

        XCTAssertTrue(service.dispatchHotKey(id: 1000))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedIDs, [manualID])
    }

    func testDockIDsStillInvokeOnlyDockCallbackWithMatchingNumberKey() {
        let expectation = expectation(description: "Dock hotkey callback")
        var receivedKeys: [NumberKey] = []
        let service = makeRegisteredService(
            onDockHotKey: { key in
                receivedKeys.append(key)
                expectation.fulfill()
            },
            onFinderHotKey: { XCTFail("Dock ID must not invoke Finder callback.") },
            onManualHotKey: { _ in XCTFail("Dock ID must not invoke manual callback.") },
            onWindowHotKey: { _ in XCTFail("Dock ID must not invoke window callback.") }
        )

        XCTAssertTrue(service.dispatchHotKey(id: 1))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedKeys, [.one])
    }

    func testUnknownIDsReturnFalseWithoutInvokingCallbacks() {
        let inverted = expectation(description: "No callback")
        inverted.isInverted = true
        let service = makeRegisteredService(
            onDockHotKey: { _ in inverted.fulfill() },
            onFinderHotKey: { inverted.fulfill() },
            onManualHotKey: { _ in inverted.fulfill() },
            onWindowHotKey: { _ in inverted.fulfill() }
        )

        XCTAssertFalse(service.dispatchHotKey(id: 9999))

        wait(for: [inverted], timeout: 0.1)
    }

    private func makeRegisteredService(
        finderShortcutEnabled: Bool = false,
        manualShortcuts: [ManualShortcut] = [],
        windowShortcuts: [WindowShortcut] = [],
        onDockHotKey: @escaping (NumberKey) -> Void = { _ in },
        onFinderHotKey: @escaping () -> Void = {},
        onManualHotKey: @escaping (UUID) -> Void = { _ in },
        onWindowHotKey: @escaping (WindowAction) -> Void = { _ in }
    ) -> GlobalHotKeyService {
        let service = GlobalHotKeyService(
            onDockHotKey: onDockHotKey,
            onFinderHotKey: onFinderHotKey,
            onManualHotKey: onManualHotKey,
            onWindowHotKey: onWindowHotKey,
            registerHotKey: { _ in HotKeyRegistrationResult(status: noErr, ref: nil) }
        )
        _ = service.register(
            modifiers: [.option],
            finderShortcutEnabled: finderShortcutEnabled,
            manualShortcuts: manualShortcuts,
            windowShortcuts: windowShortcuts
        )
        return service
    }

    private func manualShortcut(
        id: UUID = UUID(),
        keyCode: UInt32,
        modifiers: Set<ShortcutModifier>
    ) -> ManualShortcut {
        ManualShortcut(
            id: id,
            name: "Manual App",
            url: URL(fileURLWithPath: "/Applications/Manual.app"),
            bundleIdentifier: "com.example.Manual",
            keyCode: keyCode,
            keyDisplayName: "M",
            modifiers: modifiers,
            isEnabled: true
        )
    }

    private func windowShortcut(
        _ action: WindowAction,
        keyCode: UInt32,
        modifiers: Set<ShortcutModifier>
    ) -> WindowShortcut {
        WindowShortcut(
            action: action,
            keyCode: keyCode,
            keyDisplayName: action.displayName,
            modifiers: modifiers,
            isEnabled: true
        )
    }
}
