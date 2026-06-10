import Carbon
import XCTest
@testable import ZapApp
@testable import ZapCore

final class GlobalHotKeyRegistrationPlanTests: XCTestCase {
    func testFinderHotkeysKeepIDsAndOptionOnlyPhysicalKeyVariants() {
        let plan = planner.plan(
            modifiers: [.option],
            finderShortcutEnabled: true,
            manualShortcuts: [],
            windowShortcuts: []
        )

        let finderHotKeys = plan.hotKeys.filter { $0.owner == .finder }

        XCTAssertEqual(finderHotKeys.map(\.id), [100, 101, 102, 103])
        XCTAssertEqual(finderHotKeys.map(\.keyCode), [
            UInt32(kVK_ANSI_Grave),
            UInt32(kVK_JIS_Yen),
            UInt32(kVK_ANSI_Backslash),
            UInt32(kVK_ISO_Section)
        ])
        XCTAssertEqual(Set(finderHotKeys.map(\.modifiers)), [UInt32(optionKey)])
    }

    func testDockHotkeysKeepIDsAndUseSelectedDockModifiers() {
        let plan = planner.plan(
            modifiers: [.option, .command],
            finderShortcutEnabled: false,
            manualShortcuts: [],
            windowShortcuts: []
        )

        let dockHotKeys = plan.hotKeys.filter {
            if case .dock = $0.owner { true } else { false }
        }

        XCTAssertEqual(dockHotKeys.map(\.id), Array(UInt32(1)...UInt32(9)))
        XCTAssertEqual(dockHotKeys.map(\.keyCode), NumberKey.allCases.map(\.carbonKeyCode))
        XCTAssertEqual(Set(dockHotKeys.map(\.modifiers)), [UInt32(optionKey | cmdKey)])
    }

    func testManualHotkeysStartAt1000AndMapToManualShortcutIDs() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let shortcuts = [
            manualShortcut(id: firstID, name: "Terminal", keyCode: 17, modifiers: [.option, .shift]),
            manualShortcut(id: secondID, name: "Notes", keyCode: 45, modifiers: [.control, .option])
        ]

        let plan = planner.plan(
            modifiers: [.option],
            finderShortcutEnabled: false,
            manualShortcuts: shortcuts,
            windowShortcuts: []
        )

        let manualHotKeys = plan.hotKeys.compactMap { hotKey -> (UInt32, UUID)? in
            guard case let .manual(id, _) = hotKey.owner else { return nil }
            return (hotKey.id, id)
        }

        XCTAssertEqual(manualHotKeys.map(\.0), [1000, 1001])
        XCTAssertEqual(manualHotKeys.map(\.1), [firstID, secondID])
    }

    func testWindowHotkeysStartAt2000AndMapEnabledCompleteShortcutsInInputOrder() {
        let shortcuts = [
            windowShortcut(.center, keyCode: 8, modifiers: [.option, .command]),
            windowShortcut(.fullscreen, keyCode: 3, modifiers: [.control, .command]),
            windowShortcut(.leftHalf, keyCode: 123, modifiers: [.control, .option])
        ]

        let plan = planner.plan(
            modifiers: [.option],
            finderShortcutEnabled: false,
            manualShortcuts: [],
            windowShortcuts: shortcuts
        )

        let windowHotKeys = plan.hotKeys.compactMap { hotKey -> (UInt32, WindowAction)? in
            guard case let .window(action, _) = hotKey.owner else { return nil }
            return (hotKey.id, action)
        }

        XCTAssertEqual(windowHotKeys.map(\.0), [2000, 2001, 2002])
        XCTAssertEqual(windowHotKeys.map(\.1), [.center, .fullscreen, .leftHalf])
    }

    func testDisabledIncompleteWindowShortcutsAreSkipped() {
        let shortcuts = [
            windowShortcut(.center, keyCode: 8, modifiers: [.option, .command], isEnabled: false),
            windowShortcut(.fullscreen, keyCode: nil, modifiers: [.option, .command]),
            windowShortcut(.leftHalf, keyCode: 123, modifiers: []),
            windowShortcut(.rightHalf, keyCode: 124, modifiers: [.control, .option])
        ]

        let plan = planner.plan(
            modifiers: [.option],
            finderShortcutEnabled: false,
            manualShortcuts: [],
            windowShortcuts: shortcuts
        )

        let windowActions = plan.hotKeys.compactMap { hotKey -> WindowAction? in
            guard case let .window(action, _) = hotKey.owner else { return nil }
            return action
        }

        XCTAssertEqual(windowActions, [.rightHalf])
        XCTAssertEqual(plan.hotKeys.compactMap { hotKey -> UInt32? in
            guard case .window = hotKey.owner else { return nil }
            return hotKey.id
        }, [2003])
    }

    func testWindowShortcutWithEmptyDisplayNameIsSkipped() {
        let plan = planner.plan(
            modifiers: [.option],
            finderShortcutEnabled: false,
            manualShortcuts: [],
            windowShortcuts: [
                windowShortcut(.center, keyCode: 8, keyDisplayName: "", modifiers: [.option, .command]),
                windowShortcut(.rightHalf, keyCode: 124, modifiers: [.control, .option])
            ]
        )

        let windowActions = plan.hotKeys.compactMap { hotKey -> WindowAction? in
            guard case let .window(action, _) = hotKey.owner else { return nil }
            return action
        }

        XCTAssertEqual(windowActions, [.rightHalf])
    }

    func testDuplicateComboAcrossDomainsUsesOneSharedComboSet() {
        let manualID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let plan = planner.plan(
            modifiers: [.option],
            finderShortcutEnabled: true,
            manualShortcuts: [manualShortcut(id: manualID, name: "Manual Finder Conflict", keyCode: UInt32(kVK_ANSI_Grave), modifiers: [.option])],
            windowShortcuts: [windowShortcut(.fullscreen, keyCode: UInt32(kVK_ANSI_Grave), modifiers: [.option])]
        )

        XCTAssertEqual(plan.hotKeys.filter { $0.combo == HotKeyCombo(keyCode: UInt32(kVK_ANSI_Grave), modifiers: UInt32(optionKey)) }.count, 1)
        XCTAssertFalse(plan.hotKeys.contains { hotKey in
            if case .manual = hotKey.owner { true } else { false }
        })
        XCTAssertFalse(plan.hotKeys.contains { hotKey in
            if case .window = hotKey.owner { true } else { false }
        })
        XCTAssertTrue(plan.errors.contains("Some manual shortcuts could not be registered: Manual Finder Conflict (conflict)"))
        XCTAssertTrue(plan.errors.contains("Some window shortcuts could not be registered: Fullscreen (conflict)"))
    }

    func testWindowConflictReturnsExpectedErrorAndOmitsConflictingShortcut() {
        let plan = planner.plan(
            modifiers: [.option],
            finderShortcutEnabled: false,
            manualShortcuts: [manualShortcut(name: "Terminal", keyCode: 3, modifiers: [.option, .command])],
            windowShortcuts: [windowShortcut(.fullscreen, keyCode: 3, modifiers: [.option, .command])]
        )

        let windowActions = plan.hotKeys.compactMap { hotKey -> WindowAction? in
            guard case let .window(action, _) = hotKey.owner else { return nil }
            return action
        }

        XCTAssertEqual(windowActions, [])
        XCTAssertTrue(plan.errors.contains("Some window shortcuts could not be registered: Fullscreen (conflict)"))
    }

    func testEmptyDockModifiersErrorDoesNotPreventEligibleFinderManualOrWindowPlanning() {
        let manualID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
        let plan = planner.plan(
            modifiers: [],
            finderShortcutEnabled: true,
            manualShortcuts: [manualShortcut(id: manualID, name: "Terminal", keyCode: 17, modifiers: [.control])],
            windowShortcuts: [windowShortcut(.center, keyCode: 8, modifiers: [.option, .command])]
        )

        XCTAssertTrue(plan.errors.contains("Select at least one modifier key."))
        XCTAssertEqual(plan.hotKeys.filter { $0.owner == .finder }.count, 4)
        XCTAssertTrue(plan.hotKeys.contains { hotKey in
            if case let .manual(id, _) = hotKey.owner { id == manualID } else { false }
        })
        XCTAssertTrue(plan.hotKeys.contains { hotKey in
            if case let .window(action, _) = hotKey.owner { action == .center } else { false }
        })
        XCTAssertFalse(plan.hotKeys.contains { hotKey in
            if case .dock = hotKey.owner { true } else { false }
        })
    }

    func testManualAndWindowConflictProducesExactlyOneRegisteredComboAndOneConflictError() {
        let plan = planner.plan(
            modifiers: [.option],
            finderShortcutEnabled: false,
            manualShortcuts: [manualShortcut(name: "Terminal", keyCode: 123, modifiers: [.control, .option])],
            windowShortcuts: [windowShortcut(.leftHalf, keyCode: 123, modifiers: [.control, .option])]
        )

        let combo = HotKeyCombo(keyCode: 123, modifiers: UInt32(controlKey | optionKey))
        XCTAssertEqual(plan.hotKeys.filter { $0.combo == combo }.count, 1)
        XCTAssertEqual(plan.errors.filter { $0.contains("(conflict)") }, ["Some window shortcuts could not be registered: Left Half (conflict)"])
    }

    private var planner: GlobalHotKeyRegistrationPlanner {
        GlobalHotKeyRegistrationPlanner()
    }

    private func manualShortcut(
        id: UUID = UUID(),
        name: String = "Manual App",
        keyCode: UInt32?,
        modifiers: Set<ShortcutModifier>,
        isEnabled: Bool = true
    ) -> ManualShortcut {
        ManualShortcut(
            id: id,
            name: name,
            url: URL(fileURLWithPath: "/Applications/\(name).app"),
            bundleIdentifier: "com.example.\(name)",
            keyCode: keyCode,
            keyDisplayName: keyCode.map { "Key\($0)" },
            modifiers: modifiers,
            isEnabled: isEnabled
        )
    }

    private func windowShortcut(
        _ action: WindowAction,
        keyCode: UInt32?,
        keyDisplayName: String? = nil,
        modifiers: Set<ShortcutModifier>,
        isEnabled: Bool = true
    ) -> WindowShortcut {
        WindowShortcut(
            action: action,
            keyCode: keyCode,
            keyDisplayName: keyDisplayName ?? action.displayName,
            modifiers: modifiers,
            isEnabled: isEnabled
        )
    }
}

private extension PlannedHotKey {
    var combo: HotKeyCombo {
        HotKeyCombo(keyCode: keyCode, modifiers: modifiers)
    }
}
