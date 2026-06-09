# Zap Window Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Spectacle-style window management to Zap while preserving existing Dock, Finder, manual app shortcut, Sparkle, and release behavior.

**Architecture:** Implement deterministic window action models and geometry logic in `ZapCore`, then layer AppKit/Accessibility services, unified Carbon hotkey registration, and SwiftUI Settings integration in `ZapApp`. Keep Spectacle's Objective-C app shell, XIB UI, Sparkle configuration, appcast, and legacy migration out of Zap.

**Tech Stack:** Swift 5.10, SwiftPM, XCTest, SwiftUI, AppKit, Carbon, ApplicationServices Accessibility APIs, CoreGraphics.

---

## Source documents

- Design spec: `docs/superpowers/specs/2026-06-09-zap-spectacle-window-management-design.md`
- Spectacle reference project: `/Users/woosublee/Documents/dev/spectacle`
- Current app targets: `Sources/ZapCore`, `Sources/ZapApp`, `Tests/ZapCoreTests`, `Tests/ZapAppTests`
- Rename note: Snap was the previous project name; do not implement new work under untracked `Snap*` paths.

---

## Part 1: ZapCore window domain

이 fragment는 macOS AppKit/Accessibility API에 의존하지 않는 `ZapCore` window management 도메인만 구현한다. `ZapApp`, `Package.swift`, Sparkle/release 설정, untracked `Snap*` 디렉터리는 이 part에서 건드리지 않는다. 좌표계는 `ZapApp`이 정규화해 넘긴 `CGRect`를 사용하며, `ZapCore`는 `visibleFrame.minY`가 하단이고 `visibleFrame.maxY`가 상단인 순수 계산 모델로 테스트한다.

### File structure

- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowAction.swift`
  - `WindowAction`, `WindowActionCategory`를 정의하고 Settings 표시명과 grouping을 제공한다.
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowShortcut.swift`
  - action별 shortcut value object와 표시 문자열을 정의한다.
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowShortcutDefaults.swift`
  - Spectacle 기본 shortcut을 Carbon virtual key code 기반 값으로 제공한다.
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowGeometry.swift`
  - `DisplayFrame`, `WindowCalculationInput`, `WindowCalculationResult`, domain error를 정의한다.
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/ScreenDetector.swift`
  - 현재 window source display, next/previous destination display, overlap 계산을 담당한다.
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowPositionCalculator.swift`
  - fullscreen, center, halves, corners, thirds, larger/smaller, display 이동 target frame을 계산한다.
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowHistory.swift`
  - application identifier별 undo/redo frame stack을 관리한다.
- Create: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/WindowActionTests.swift`
- Create: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/WindowShortcutTests.swift`
- Create: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/WindowShortcutDefaultsTests.swift`
- Create: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/ScreenDetectorTests.swift`
- Create: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/WindowPositionCalculatorTests.swift`
- Create: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/WindowHistoryTests.swift`

---

### Task 1: WindowAction domain enum

**Files:**
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowAction.swift`
- Test: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/WindowActionTests.swift`

**Steps:**

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ZapCore

final class WindowActionTests: XCTestCase {
    func testAllActionsUseSpectacleOrder() {
        XCTAssertEqual(WindowAction.allCases, [
            .center,
            .fullscreen,
            .leftHalf,
            .rightHalf,
            .topHalf,
            .bottomHalf,
            .upperLeft,
            .upperRight,
            .lowerLeft,
            .lowerRight,
            .nextDisplay,
            .previousDisplay,
            .nextThird,
            .previousThird,
            .larger,
            .smaller,
            .undo,
            .redo
        ])
    }

    func testDisplayNamesMatchSettingsLabels() {
        XCTAssertEqual(WindowAction.center.displayName, "Center")
        XCTAssertEqual(WindowAction.fullscreen.displayName, "Fullscreen")
        XCTAssertEqual(WindowAction.leftHalf.displayName, "Left Half")
        XCTAssertEqual(WindowAction.rightHalf.displayName, "Right Half")
        XCTAssertEqual(WindowAction.topHalf.displayName, "Top Half")
        XCTAssertEqual(WindowAction.bottomHalf.displayName, "Bottom Half")
        XCTAssertEqual(WindowAction.upperLeft.displayName, "Upper Left")
        XCTAssertEqual(WindowAction.upperRight.displayName, "Upper Right")
        XCTAssertEqual(WindowAction.lowerLeft.displayName, "Lower Left")
        XCTAssertEqual(WindowAction.lowerRight.displayName, "Lower Right")
        XCTAssertEqual(WindowAction.nextDisplay.displayName, "Next Display")
        XCTAssertEqual(WindowAction.previousDisplay.displayName, "Previous Display")
        XCTAssertEqual(WindowAction.nextThird.displayName, "Next Third")
        XCTAssertEqual(WindowAction.previousThird.displayName, "Previous Third")
        XCTAssertEqual(WindowAction.larger.displayName, "Larger")
        XCTAssertEqual(WindowAction.smaller.displayName, "Smaller")
        XCTAssertEqual(WindowAction.undo.displayName, "Undo")
        XCTAssertEqual(WindowAction.redo.displayName, "Redo")
    }

    func testCategoriesSeparatePositioningDisplaySizingAndHistory() {
        XCTAssertEqual(WindowAction.center.category, .positioning)
        XCTAssertEqual(WindowAction.upperRight.category, .positioning)
        XCTAssertEqual(WindowAction.nextDisplay.category, .display)
        XCTAssertEqual(WindowAction.previousDisplay.category, .display)
        XCTAssertEqual(WindowAction.nextThird.category, .sizing)
        XCTAssertEqual(WindowAction.larger.category, .sizing)
        XCTAssertEqual(WindowAction.undo.category, .history)
        XCTAssertEqual(WindowAction.redo.category, .history)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowActionTests
```

Expected: command exits non-zero with compile errors containing `cannot find 'WindowAction' in scope` or `cannot find type 'WindowAction' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowAction.swift`:

```swift
public enum WindowActionCategory: String, Codable, Equatable, Sendable {
    case positioning
    case display
    case sizing
    case history
}

public enum WindowAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case center
    case fullscreen
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case upperLeft
    case upperRight
    case lowerLeft
    case lowerRight
    case nextDisplay
    case previousDisplay
    case nextThird
    case previousThird
    case larger
    case smaller
    case undo
    case redo

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .center: "Center"
        case .fullscreen: "Fullscreen"
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .upperLeft: "Upper Left"
        case .upperRight: "Upper Right"
        case .lowerLeft: "Lower Left"
        case .lowerRight: "Lower Right"
        case .nextDisplay: "Next Display"
        case .previousDisplay: "Previous Display"
        case .nextThird: "Next Third"
        case .previousThird: "Previous Third"
        case .larger: "Larger"
        case .smaller: "Smaller"
        case .undo: "Undo"
        case .redo: "Redo"
        }
    }

    public var category: WindowActionCategory {
        switch self {
        case .center, .fullscreen, .leftHalf, .rightHalf, .topHalf, .bottomHalf,
             .upperLeft, .upperRight, .lowerLeft, .lowerRight:
            .positioning
        case .nextDisplay, .previousDisplay:
            .display
        case .nextThird, .previousThird, .larger, .smaller:
            .sizing
        case .undo, .redo:
            .history
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowActionTests
```

Expected: `WindowActionTests` passes.

- [ ] **Step 5: Commit**

```bash
cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowAction.swift Tests/ZapCoreTests/WindowActionTests.swift && git commit -m "feat: add window action domain"
```

**실행 명령:**
- Fail 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowActionTests`
- Pass 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowActionTests`
- Commit: `cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowAction.swift Tests/ZapCoreTests/WindowActionTests.swift && git commit -m "feat: add window action domain"`

**예상 결과:** 첫 실행은 `WindowAction` 미정의 compile failure이고, 구현 후 실행은 pass이며, commit은 두 신규 파일만 포함한다.

---

### Task 2: WindowShortcut value object

**Files:**
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowShortcut.swift`
- Test: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/WindowShortcutTests.swift`

**Steps:**

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ZapCore

final class WindowShortcutTests: XCTestCase {
    func testShortcutIdentityUsesAction() {
        let shortcut = WindowShortcut(
            action: .center,
            keyCode: 8,
            keyDisplayName: "C",
            modifiers: [.option, .command],
            isEnabled: true
        )

        XCTAssertEqual(shortcut.id, WindowAction.center.id)
    }

    func testDisplayTextUsesStableModifierOrder() {
        let shortcut = WindowShortcut(
            action: .lowerLeft,
            keyCode: 123,
            keyDisplayName: "←",
            modifiers: [.command, .shift, .control],
            isEnabled: true
        )

        XCTAssertEqual(shortcut.displayText, "⌃⇧⌘←")
    }

    func testDisabledOrIncompleteShortcutDisplaysOff() {
        XCTAssertEqual(WindowShortcut(action: .center, keyCode: 8, keyDisplayName: "C", modifiers: [.option], isEnabled: false).displayText, "Off")
        XCTAssertEqual(WindowShortcut(action: .center, keyCode: nil, keyDisplayName: nil, modifiers: [.option], isEnabled: true).displayText, "Off")
        XCTAssertEqual(WindowShortcut(action: .center, keyCode: 8, keyDisplayName: "C", modifiers: [], isEnabled: true).displayText, "Off")
    }

    func testShortcutCodableRoundTrip() throws {
        let shortcut = WindowShortcut(
            action: .redo,
            keyCode: 6,
            keyDisplayName: "Z",
            modifiers: [.option, .shift, .command],
            isEnabled: true
        )

        let data = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(WindowShortcut.self, from: data)

        XCTAssertEqual(decoded, shortcut)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowShortcutTests
```

Expected: command exits non-zero with compile errors containing `cannot find 'WindowShortcut' in scope` or `cannot find type 'WindowShortcut' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowShortcut.swift`:

```swift
public struct WindowShortcut: Codable, Equatable, Identifiable, Sendable {
    public var action: WindowAction
    public var keyCode: UInt32?
    public var keyDisplayName: String?
    public var modifiers: Set<ShortcutModifier>
    public var isEnabled: Bool

    public var id: String { action.id }

    public init(
        action: WindowAction,
        keyCode: UInt32?,
        keyDisplayName: String?,
        modifiers: Set<ShortcutModifier>,
        isEnabled: Bool
    ) {
        self.action = action
        self.keyCode = keyCode
        self.keyDisplayName = keyDisplayName
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }

    public var displayText: String {
        guard isEnabled, keyCode != nil, let keyDisplayName, !modifiers.isEmpty else {
            return "Off"
        }

        let modifierSymbols = modifiers
            .sorted { $0.windowShortcutDisplayOrder < $1.windowShortcutDisplayOrder }
            .map(\.symbol)
            .joined()

        return modifierSymbols + keyDisplayName
    }
}

private extension ShortcutModifier {
    var windowShortcutDisplayOrder: Int {
        switch self {
        case .control: 0
        case .option: 1
        case .shift: 2
        case .command: 3
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowShortcutTests
```

Expected: `WindowShortcutTests` passes.

- [ ] **Step 5: Commit**

```bash
cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowShortcut.swift Tests/ZapCoreTests/WindowShortcutTests.swift && git commit -m "feat: add window shortcut value object"
```

**실행 명령:**
- Fail 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowShortcutTests`
- Pass 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowShortcutTests`
- Commit: `cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowShortcut.swift Tests/ZapCoreTests/WindowShortcutTests.swift && git commit -m "feat: add window shortcut value object"`

**예상 결과:** 첫 실행은 `WindowShortcut` 미정의 compile failure이고, 구현 후 실행은 pass이며, commit은 `WindowShortcut`과 해당 테스트만 포함한다.

---

### Task 3: WindowShortcutDefaults Spectacle shortcuts

**Files:**
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowShortcutDefaults.swift`
- Test: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/WindowShortcutDefaultsTests.swift`

**Steps:**

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import ZapCore

final class WindowShortcutDefaultsTests: XCTestCase {
    func testDefaultsContainOneEnabledShortcutPerAction() {
        XCTAssertEqual(WindowShortcutDefaults.all.map(\.action), WindowAction.allCases)
        XCTAssertEqual(WindowShortcutDefaults.all.count, 18)
        XCTAssertTrue(WindowShortcutDefaults.all.allSatisfy(\.isEnabled))
    }

    func testLetterShortcutDefaults() {
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .center), WindowShortcut(action: .center, keyCode: 8, keyDisplayName: "C", modifiers: [.option, .command], isEnabled: true))
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .fullscreen), WindowShortcut(action: .fullscreen, keyCode: 3, keyDisplayName: "F", modifiers: [.option, .command], isEnabled: true))
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .undo), WindowShortcut(action: .undo, keyCode: 6, keyDisplayName: "Z", modifiers: [.option, .command], isEnabled: true))
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .redo), WindowShortcut(action: .redo, keyCode: 6, keyDisplayName: "Z", modifiers: [.option, .shift, .command], isEnabled: true))
    }

    func testArrowShortcutDisplaysMatchSpectacleDefaults() {
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .leftHalf).displayText, "⌥⌘←")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .rightHalf).displayText, "⌥⌘→")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .topHalf).displayText, "⌥⌘↑")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .bottomHalf).displayText, "⌥⌘↓")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .upperLeft).displayText, "⌃⌘←")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .lowerLeft).displayText, "⌃⇧⌘←")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .upperRight).displayText, "⌃⌘→")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .lowerRight).displayText, "⌃⇧⌘→")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .nextDisplay).displayText, "⌃⌥⌘→")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .previousDisplay).displayText, "⌃⌥⌘←")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .nextThird).displayText, "⌃⌥→")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .previousThird).displayText, "⌃⌥←")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .larger).displayText, "⌃⌥⇧→")
        XCTAssertEqual(WindowShortcutDefaults.shortcut(for: .smaller).displayText, "⌃⌥⇧←")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowShortcutDefaultsTests
```

Expected: command exits non-zero with compile errors containing `cannot find 'WindowShortcutDefaults' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowShortcutDefaults.swift`:

```swift
public enum WindowShortcutDefaults {
    public static let cKeyCode: UInt32 = 8
    public static let fKeyCode: UInt32 = 3
    public static let zKeyCode: UInt32 = 6
    public static let leftArrowKeyCode: UInt32 = 123
    public static let rightArrowKeyCode: UInt32 = 124
    public static let downArrowKeyCode: UInt32 = 125
    public static let upArrowKeyCode: UInt32 = 126

    public static let all: [WindowShortcut] = [
        shortcut(.center, cKeyCode, "C", [.option, .command]),
        shortcut(.fullscreen, fKeyCode, "F", [.option, .command]),
        shortcut(.leftHalf, leftArrowKeyCode, "←", [.option, .command]),
        shortcut(.rightHalf, rightArrowKeyCode, "→", [.option, .command]),
        shortcut(.topHalf, upArrowKeyCode, "↑", [.option, .command]),
        shortcut(.bottomHalf, downArrowKeyCode, "↓", [.option, .command]),
        shortcut(.upperLeft, leftArrowKeyCode, "←", [.control, .command]),
        shortcut(.upperRight, rightArrowKeyCode, "→", [.control, .command]),
        shortcut(.lowerLeft, leftArrowKeyCode, "←", [.control, .shift, .command]),
        shortcut(.lowerRight, rightArrowKeyCode, "→", [.control, .shift, .command]),
        shortcut(.nextDisplay, rightArrowKeyCode, "→", [.control, .option, .command]),
        shortcut(.previousDisplay, leftArrowKeyCode, "←", [.control, .option, .command]),
        shortcut(.nextThird, rightArrowKeyCode, "→", [.control, .option]),
        shortcut(.previousThird, leftArrowKeyCode, "←", [.control, .option]),
        shortcut(.larger, rightArrowKeyCode, "→", [.control, .option, .shift]),
        shortcut(.smaller, leftArrowKeyCode, "←", [.control, .option, .shift]),
        shortcut(.undo, zKeyCode, "Z", [.option, .command]),
        shortcut(.redo, zKeyCode, "Z", [.option, .shift, .command])
    ]

    public static func shortcut(for action: WindowAction) -> WindowShortcut {
        guard let value = all.first(where: { $0.action == action }) else {
            preconditionFailure("Missing default window shortcut for \(action.rawValue)")
        }
        return value
    }

    private static func shortcut(
        _ action: WindowAction,
        _ keyCode: UInt32,
        _ keyDisplayName: String,
        _ modifiers: Set<ShortcutModifier>
    ) -> WindowShortcut {
        WindowShortcut(
            action: action,
            keyCode: keyCode,
            keyDisplayName: keyDisplayName,
            modifiers: modifiers,
            isEnabled: true
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowShortcutDefaultsTests
```

Expected: `WindowShortcutDefaultsTests` passes.

- [ ] **Step 5: Commit**

```bash
cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowShortcutDefaults.swift Tests/ZapCoreTests/WindowShortcutDefaultsTests.swift && git commit -m "feat: add default window shortcuts"
```

**실행 명령:**
- Fail 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowShortcutDefaultsTests`
- Pass 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowShortcutDefaultsTests`
- Commit: `cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowShortcutDefaults.swift Tests/ZapCoreTests/WindowShortcutDefaultsTests.swift && git commit -m "feat: add default window shortcuts"`

**예상 결과:** 첫 실행은 `WindowShortcutDefaults` 미정의 compile failure이고, 구현 후 모든 Spectacle shortcut 표시 문자열이 pass한다.

---

### Task 4: ScreenDetector and geometry models

**Files:**
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowGeometry.swift`
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/ScreenDetector.swift`
- Test: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/ScreenDetectorTests.swift`

**Steps:**

- [ ] **Step 1: Write the failing test**

```swift
import CoreGraphics
import XCTest
@testable import ZapCore

final class ScreenDetectorTests: XCTestCase {
    private let leftDisplay = DisplayFrame(
        frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
        visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875),
        isMain: true
    )

    private let rightDisplay = DisplayFrame(
        frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055),
        isMain: false
    )

    func testOverlapAreaUsesIntersectionArea() {
        let detector = ScreenDetector()
        let window = CGRect(x: 1200, y: 100, width: 600, height: 400)

        XCTAssertEqual(detector.overlapArea(window, leftDisplay.frame), 240 * 400, accuracy: 0.001)
        XCTAssertEqual(detector.overlapArea(window, rightDisplay.frame), 360 * 400, accuracy: 0.001)
    }

    func testSourceDisplayChoosesLargestOverlap() throws {
        let detector = ScreenDetector()
        let window = CGRect(x: 1200, y: 100, width: 600, height: 400)

        let source = try detector.sourceDisplay(for: window, displays: [leftDisplay, rightDisplay])

        XCTAssertEqual(source, rightDisplay)
    }

    func testSourceDisplayFallsBackToMainDisplayWhenWindowHasNoOverlap() throws {
        let detector = ScreenDetector()
        let window = CGRect(x: -900, y: -900, width: 200, height: 200)

        let source = try detector.sourceDisplay(for: window, displays: [leftDisplay, rightDisplay])

        XCTAssertEqual(source, leftDisplay)
    }

    func testDestinationDisplayWrapsInHorizontalOrder() throws {
        let detector = ScreenDetector()
        let displays = [leftDisplay, rightDisplay]

        XCTAssertEqual(try detector.destinationDisplay(for: .nextDisplay, source: leftDisplay, displays: displays), rightDisplay)
        XCTAssertEqual(try detector.destinationDisplay(for: .nextDisplay, source: rightDisplay, displays: displays), leftDisplay)
        XCTAssertEqual(try detector.destinationDisplay(for: .previousDisplay, source: leftDisplay, displays: displays), rightDisplay)
        XCTAssertEqual(try detector.destinationDisplay(for: .previousDisplay, source: rightDisplay, displays: displays), leftDisplay)
    }

    func testEmptyDisplaysThrowNoDisplays() {
        let detector = ScreenDetector()

        XCTAssertThrowsError(try detector.sourceDisplay(for: .zero, displays: [])) { error in
            XCTAssertEqual(error as? WindowDomainError, .noDisplays)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter ScreenDetectorTests
```

Expected: command exits non-zero with compile errors containing `cannot find 'DisplayFrame' in scope` and `cannot find 'ScreenDetector' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowGeometry.swift`:

```swift
import CoreGraphics

public struct DisplayFrame: Equatable, Sendable {
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let isMain: Bool

    public init(frame: CGRect, visibleFrame: CGRect, isMain: Bool) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.isMain = isMain
    }
}

public struct WindowCalculationInput: Equatable, Sendable {
    public let windowFrame: CGRect
    public let sourceVisibleFrame: CGRect
    public let destinationVisibleFrame: CGRect
    public let action: WindowAction

    public init(
        windowFrame: CGRect,
        sourceVisibleFrame: CGRect,
        destinationVisibleFrame: CGRect,
        action: WindowAction
    ) {
        self.windowFrame = windowFrame
        self.sourceVisibleFrame = sourceVisibleFrame
        self.destinationVisibleFrame = destinationVisibleFrame
        self.action = action
    }
}

public struct WindowCalculationResult: Equatable, Sendable {
    public let frame: CGRect
    public let resolvedAction: WindowAction

    public init(frame: CGRect, resolvedAction: WindowAction) {
        self.frame = frame
        self.resolvedAction = resolvedAction
    }
}

public enum WindowDomainError: Error, Equatable, Sendable {
    case noDisplays
    case unsupportedDisplayAction(WindowAction)
}
```

Create `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/ScreenDetector.swift`:

```swift
import CoreGraphics

public struct ScreenDetector: Sendable {
    public init() {}

    public func overlapArea(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        return intersection.width * intersection.height
    }

    public func sourceDisplay(for windowFrame: CGRect, displays: [DisplayFrame]) throws -> DisplayFrame {
        guard !displays.isEmpty else { throw WindowDomainError.noDisplays }

        let ranked = displays.map { display in
            (display: display, area: overlapArea(windowFrame, display.frame))
        }

        if let match = ranked.max(by: { $0.area < $1.area }), match.area > 0 {
            return match.display
        }

        return displays.first(where: \.isMain) ?? displays[0]
    }

    public func destinationDisplay(
        for action: WindowAction,
        source: DisplayFrame,
        displays: [DisplayFrame]
    ) throws -> DisplayFrame {
        guard !displays.isEmpty else { throw WindowDomainError.noDisplays }
        guard action == .nextDisplay || action == .previousDisplay else {
            throw WindowDomainError.unsupportedDisplayAction(action)
        }

        let ordered = displays.sorted {
            if $0.frame.minX == $1.frame.minX {
                return $0.frame.minY < $1.frame.minY
            }
            return $0.frame.minX < $1.frame.minX
        }

        guard let index = ordered.firstIndex(of: source) else {
            return ordered.first(where: \.isMain) ?? ordered[0]
        }

        switch action {
        case .nextDisplay:
            return ordered[(index + 1) % ordered.count]
        case .previousDisplay:
            return ordered[(index - 1 + ordered.count) % ordered.count]
        default:
            throw WindowDomainError.unsupportedDisplayAction(action)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter ScreenDetectorTests
```

Expected: `ScreenDetectorTests` passes.

- [ ] **Step 5: Commit**

```bash
cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowGeometry.swift Sources/ZapCore/ScreenDetector.swift Tests/ZapCoreTests/ScreenDetectorTests.swift && git commit -m "feat: add screen detection domain"
```

**실행 명령:**
- Fail 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter ScreenDetectorTests`
- Pass 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter ScreenDetectorTests`
- Commit: `cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowGeometry.swift Sources/ZapCore/ScreenDetector.swift Tests/ZapCoreTests/ScreenDetectorTests.swift && git commit -m "feat: add screen detection domain"`

**예상 결과:** 첫 실행은 geometry/screen detector 타입 미정의 compile failure이고, 구현 후 overlap/source/destination display tests가 pass한다.

---

### Task 5: WindowPositionCalculator fixed positions

**Files:**
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowPositionCalculator.swift`
- Test: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/WindowPositionCalculatorTests.swift`

**Steps:**

- [ ] **Step 1: Write the failing test**

```swift
import CoreGraphics
import XCTest
@testable import ZapCore

final class WindowPositionCalculatorTests: XCTestCase {
    private let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)

    func testFullscreenUsesDestinationVisibleFrame() {
        let result = calculate(.fullscreen, window: CGRect(x: 100, y: 100, width: 400, height: 300))

        XCTAssertEqual(result.frame, visible)
        XCTAssertEqual(result.resolvedAction, .fullscreen)
    }

    func testCenterPreservesWindowSizeAndCentersInVisibleFrame() {
        let result = calculate(.center, window: CGRect(x: 0, y: 25, width: 400, height: 300))

        XCTAssertEqual(result.frame.origin.x, 520, accuracy: 0.001)
        XCTAssertEqual(result.frame.origin.y, 462.5, accuracy: 0.001)
        XCTAssertEqual(result.frame.width, 400, accuracy: 0.001)
        XCTAssertEqual(result.frame.height, 300, accuracy: 0.001)
    }

    func testHalvesUseVisibleFrame() {
        XCTAssertEqual(calculate(.leftHalf).frame, CGRect(x: 0, y: 25, width: 720, height: 875))
        XCTAssertEqual(calculate(.rightHalf).frame, CGRect(x: 720, y: 25, width: 720, height: 875))
        XCTAssertEqual(calculate(.topHalf).frame, CGRect(x: 0, y: 462.5, width: 1440, height: 437.5))
        XCTAssertEqual(calculate(.bottomHalf).frame, CGRect(x: 0, y: 25, width: 1440, height: 437.5))
    }

    func testCornersUseVisibleFrameQuadrants() {
        XCTAssertEqual(calculate(.upperLeft).frame, CGRect(x: 0, y: 462.5, width: 720, height: 437.5))
        XCTAssertEqual(calculate(.upperRight).frame, CGRect(x: 720, y: 462.5, width: 720, height: 437.5))
        XCTAssertEqual(calculate(.lowerLeft).frame, CGRect(x: 0, y: 25, width: 720, height: 437.5))
        XCTAssertEqual(calculate(.lowerRight).frame, CGRect(x: 720, y: 25, width: 720, height: 437.5))
    }

    private func calculate(
        _ action: WindowAction,
        window: CGRect = CGRect(x: 100, y: 100, width: 600, height: 400)
    ) -> WindowCalculationResult {
        WindowPositionCalculator().calculate(WindowCalculationInput(
            windowFrame: window,
            sourceVisibleFrame: visible,
            destinationVisibleFrame: visible,
            action: action
        ))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowPositionCalculatorTests
```

Expected: command exits non-zero with compile errors containing `cannot find 'WindowPositionCalculator' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowPositionCalculator.swift` with the fixed-position branches first:

```swift
import CoreGraphics

public struct WindowPositionCalculator: Sendable {
    public init() {}

    public func calculate(_ input: WindowCalculationInput) -> WindowCalculationResult {
        let frame: CGRect

        switch input.action {
        case .fullscreen:
            frame = input.destinationVisibleFrame
        case .center:
            frame = centered(input.windowFrame, in: input.destinationVisibleFrame)
        case .leftHalf:
            frame = fractionRect(in: input.destinationVisibleFrame, x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf:
            frame = fractionRect(in: input.destinationVisibleFrame, x: 0.5, y: 0, width: 0.5, height: 1)
        case .topHalf:
            frame = fractionRect(in: input.destinationVisibleFrame, x: 0, y: 0.5, width: 1, height: 0.5)
        case .bottomHalf:
            frame = fractionRect(in: input.destinationVisibleFrame, x: 0, y: 0, width: 1, height: 0.5)
        case .upperLeft:
            frame = fractionRect(in: input.destinationVisibleFrame, x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .upperRight:
            frame = fractionRect(in: input.destinationVisibleFrame, x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .lowerLeft:
            frame = fractionRect(in: input.destinationVisibleFrame, x: 0, y: 0, width: 0.5, height: 0.5)
        case .lowerRight:
            frame = fractionRect(in: input.destinationVisibleFrame, x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .nextDisplay, .previousDisplay:
            frame = moveBetweenDisplays(input.windowFrame, from: input.sourceVisibleFrame, to: input.destinationVisibleFrame)
        case .nextThird:
            frame = third(afterCurrentWindowIn: input)
        case .previousThird:
            frame = third(beforeCurrentWindowIn: input)
        case .larger:
            frame = resized(input.windowFrame, in: input.destinationVisibleFrame, scaleDelta: 1.0 / 6.0)
        case .smaller:
            frame = resized(input.windowFrame, in: input.destinationVisibleFrame, scaleDelta: -1.0 / 6.0)
        case .undo, .redo:
            frame = input.windowFrame
        }

        return WindowCalculationResult(frame: frame.integralIfClose, resolvedAction: input.action)
    }

    private func fractionRect(in visibleFrame: CGRect, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(
            x: visibleFrame.minX + visibleFrame.width * x,
            y: visibleFrame.minY + visibleFrame.height * y,
            width: visibleFrame.width * width,
            height: visibleFrame.height * height
        )
    }

    private func centered(_ windowFrame: CGRect, in visibleFrame: CGRect) -> CGRect {
        let width = min(windowFrame.width, visibleFrame.width)
        let height = min(windowFrame.height, visibleFrame.height)
        return CGRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }
}

private extension CGRect {
    var integralIfClose: CGRect {
        CGRect(
            x: origin.x.roundedToPixelIfClose,
            y: origin.y.roundedToPixelIfClose,
            width: size.width.roundedToPixelIfClose,
            height: size.height.roundedToPixelIfClose
        )
    }
}

private extension CGFloat {
    var roundedToPixelIfClose: CGFloat {
        let rounded = self.rounded()
        return abs(self - rounded) < 0.0001 ? rounded : self
    }
}
```

At the end of this task, add private method stubs with deterministic bodies so the file compiles before Task 6 expands them:

```swift
private extension WindowPositionCalculator {
    func moveBetweenDisplays(_ windowFrame: CGRect, from source: CGRect, to destination: CGRect) -> CGRect {
        windowFrame.offsetBy(dx: destination.minX - source.minX, dy: destination.minY - source.minY)
    }

    func third(afterCurrentWindowIn input: WindowCalculationInput) -> CGRect {
        fractionRect(in: input.destinationVisibleFrame, x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1)
    }

    func third(beforeCurrentWindowIn input: WindowCalculationInput) -> CGRect {
        fractionRect(in: input.destinationVisibleFrame, x: 0, y: 0, width: 1.0 / 3.0, height: 1)
    }

    func resized(_ windowFrame: CGRect, in visibleFrame: CGRect, scaleDelta: CGFloat) -> CGRect {
        centered(windowFrame, in: visibleFrame)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowPositionCalculatorTests
```

Expected: fixed-position tests pass. Task 6 will replace the deterministic bodies for display movement, thirds, and larger/smaller with tested implementations.

- [ ] **Step 5: Commit**

```bash
cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowPositionCalculator.swift Tests/ZapCoreTests/WindowPositionCalculatorTests.swift && git commit -m "feat: calculate fixed window positions"
```

**실행 명령:**
- Fail 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowPositionCalculatorTests`
- Pass 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowPositionCalculatorTests`
- Commit: `cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowPositionCalculator.swift Tests/ZapCoreTests/WindowPositionCalculatorTests.swift && git commit -m "feat: calculate fixed window positions"`

**예상 결과:** 첫 실행은 calculator 미정의 compile failure이고, 구현 후 fullscreen/center/halves/corners 계산 tests가 pass한다.

---

### Task 6: WindowPositionCalculator thirds, resizing, and display movement

**Files:**
- Modify: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowPositionCalculator.swift`
- Modify: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/WindowPositionCalculatorTests.swift`

**Steps:**

- [ ] **Step 1: Write the failing test**

Append these tests to `WindowPositionCalculatorTests`:

```swift
extension WindowPositionCalculatorTests {
    func testNextAndPreviousThirdCycleAcrossLeftCenterRightThirds() {
        let leftThird = CGRect(x: 0, y: 25, width: 480, height: 875)
        let centerThird = CGRect(x: 480, y: 25, width: 480, height: 875)
        let rightThird = CGRect(x: 960, y: 25, width: 480, height: 875)

        XCTAssertEqual(calculate(.nextThird, window: leftThird).frame, centerThird)
        XCTAssertEqual(calculate(.nextThird, window: centerThird).frame, rightThird)
        XCTAssertEqual(calculate(.nextThird, window: rightThird).frame, leftThird)
        XCTAssertEqual(calculate(.previousThird, window: leftThird).frame, rightThird)
        XCTAssertEqual(calculate(.previousThird, window: centerThird).frame, leftThird)
        XCTAssertEqual(calculate(.previousThird, window: rightThird).frame, centerThird)
    }

    func testLargerExpandsAroundCenterAndClampsToVisibleFrame() {
        let result = calculate(.larger, window: CGRect(x: 480, y: 300, width: 480, height: 300))

        XCTAssertEqual(result.frame.origin.x, 360, accuracy: 0.001)
        XCTAssertEqual(result.frame.origin.y, 227.0833333333, accuracy: 0.001)
        XCTAssertEqual(result.frame.width, 720, accuracy: 0.001)
        XCTAssertEqual(result.frame.height, 445.8333333333, accuracy: 0.001)
    }

    func testSmallerShrinksAroundCenterWithOneThirdMinimum() {
        let result = calculate(.smaller, window: CGRect(x: 360, y: 227.0833333333, width: 720, height: 445.8333333333))

        XCTAssertEqual(result.frame.origin.x, 480, accuracy: 0.001)
        XCTAssertEqual(result.frame.origin.y, 300, accuracy: 0.001)
        XCTAssertEqual(result.frame.width, 480, accuracy: 0.001)
        XCTAssertEqual(result.frame.height, 300, accuracy: 0.001)
    }

    func testDisplayMovementPreservesRelativeVisibleFramePositionAndSize() {
        let source = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let destination = CGRect(x: 1440, y: 25, width: 1920, height: 1055)
        let input = WindowCalculationInput(
            windowFrame: CGRect(x: 360, y: 200, width: 720, height: 437.5),
            sourceVisibleFrame: source,
            destinationVisibleFrame: destination,
            action: .nextDisplay
        )

        let result = WindowPositionCalculator().calculate(input)

        XCTAssertEqual(result.frame.origin.x, 1920, accuracy: 0.001)
        XCTAssertEqual(result.frame.origin.y, 236, accuracy: 0.001)
        XCTAssertEqual(result.frame.width, 960, accuracy: 0.001)
        XCTAssertEqual(result.frame.height, 527.5, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowPositionCalculatorTests
```

Expected: command exits non-zero. The newly appended tests fail because Task 5's deterministic bodies do not yet calculate third cycling, resizing, or proportional display movement.

- [ ] **Step 3: Write minimal implementation**

Replace the private extension methods added in Task 5 with these implementations:

```swift
private extension WindowPositionCalculator {
    func moveBetweenDisplays(_ windowFrame: CGRect, from source: CGRect, to destination: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return centered(windowFrame, in: destination) }

        let xRatio = (windowFrame.minX - source.minX) / source.width
        let yRatio = (windowFrame.minY - source.minY) / source.height
        let widthRatio = windowFrame.width / source.width
        let heightRatio = windowFrame.height / source.height

        return CGRect(
            x: destination.minX + destination.width * xRatio,
            y: destination.minY + destination.height * yRatio,
            width: destination.width * widthRatio,
            height: destination.height * heightRatio
        )
    }

    func third(afterCurrentWindowIn input: WindowCalculationInput) -> CGRect {
        third(in: input.destinationVisibleFrame, currentWindow: input.windowFrame, offset: 1)
    }

    func third(beforeCurrentWindowIn input: WindowCalculationInput) -> CGRect {
        third(in: input.destinationVisibleFrame, currentWindow: input.windowFrame, offset: -1)
    }

    func third(in visibleFrame: CGRect, currentWindow: CGRect, offset: Int) -> CGRect {
        let thirdWidth = visibleFrame.width / 3
        let thirdOrigins = [visibleFrame.minX, visibleFrame.minX + thirdWidth, visibleFrame.minX + thirdWidth * 2]
        let currentIndex = thirdOrigins.enumerated().min { left, right in
            abs(currentWindow.minX - left.element) < abs(currentWindow.minX - right.element)
        }?.offset ?? 0
        let targetIndex = (currentIndex + offset + thirdOrigins.count) % thirdOrigins.count

        return CGRect(
            x: thirdOrigins[targetIndex],
            y: visibleFrame.minY,
            width: thirdWidth,
            height: visibleFrame.height
        )
    }

    func resized(_ windowFrame: CGRect, in visibleFrame: CGRect, scaleDelta: CGFloat) -> CGRect {
        let targetWidth = clamp(
            windowFrame.width + visibleFrame.width * scaleDelta,
            minimum: visibleFrame.width / 3,
            maximum: visibleFrame.width
        )
        let targetHeight = clamp(
            windowFrame.height + visibleFrame.height * scaleDelta,
            minimum: visibleFrame.height / 3,
            maximum: visibleFrame.height
        )

        let centeredFrame = CGRect(
            x: windowFrame.midX - targetWidth / 2,
            y: windowFrame.midY - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )

        return clamped(centeredFrame, to: visibleFrame)
    }

    func clamp(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum)
    }

    func clamped(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        let x = clamp(frame.minX, minimum: visibleFrame.minX, maximum: visibleFrame.maxX - frame.width)
        let y = clamp(frame.minY, minimum: visibleFrame.minY, maximum: visibleFrame.maxY - frame.height)
        return CGRect(x: x, y: y, width: frame.width, height: frame.height)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowPositionCalculatorTests
```

Expected: all fixed-position, thirds, resizing, and display movement calculator tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowPositionCalculator.swift Tests/ZapCoreTests/WindowPositionCalculatorTests.swift && git commit -m "feat: calculate advanced window positions"
```

**실행 명령:**
- Fail 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowPositionCalculatorTests`
- Pass 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowPositionCalculatorTests`
- Commit: `cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowPositionCalculator.swift Tests/ZapCoreTests/WindowPositionCalculatorTests.swift && git commit -m "feat: calculate advanced window positions"`

**예상 결과:** 첫 실행은 newly appended tests가 fail하고, 구현 후 `WindowPositionCalculatorTests` 전체가 pass한다.

---

### Task 7: WindowHistory undo and redo stacks

**Files:**
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowHistory.swift`
- Test: `/Users/woosublee/Documents/dev/zap/Tests/ZapCoreTests/WindowHistoryTests.swift`

**Steps:**

- [ ] **Step 1: Write the failing test**

```swift
import CoreGraphics
import XCTest
@testable import ZapCore

final class WindowHistoryTests: XCTestCase {
    func testRecordEnablesUndoForApplicationIdentifier() {
        var history = WindowHistory()
        let frame = CGRect(x: 10, y: 20, width: 300, height: 400)

        history.record(applicationIdentifier: "com.example.Terminal", frame: frame)

        XCTAssertTrue(history.canUndo(applicationIdentifier: "com.example.Terminal"))
        XCTAssertFalse(history.canRedo(applicationIdentifier: "com.example.Terminal"))
    }

    func testUndoReturnsLastFrameAndStoresCurrentFrameForRedo() {
        var history = WindowHistory()
        let previous = CGRect(x: 10, y: 20, width: 300, height: 400)
        let current = CGRect(x: 0, y: 25, width: 1440, height: 875)

        history.record(applicationIdentifier: "com.example.Terminal", frame: previous)
        let undoItem = history.undo(applicationIdentifier: "com.example.Terminal", currentFrame: current)

        XCTAssertEqual(undoItem, WindowHistoryItem(applicationIdentifier: "com.example.Terminal", windowFrame: previous))
        XCTAssertFalse(history.canUndo(applicationIdentifier: "com.example.Terminal"))
        XCTAssertTrue(history.canRedo(applicationIdentifier: "com.example.Terminal"))
    }

    func testRedoReturnsFrameCapturedDuringUndo() {
        var history = WindowHistory()
        let previous = CGRect(x: 10, y: 20, width: 300, height: 400)
        let current = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let afterUndo = previous

        history.record(applicationIdentifier: "com.example.Terminal", frame: previous)
        _ = history.undo(applicationIdentifier: "com.example.Terminal", currentFrame: current)
        let redoItem = history.redo(applicationIdentifier: "com.example.Terminal", currentFrame: afterUndo)

        XCTAssertEqual(redoItem, WindowHistoryItem(applicationIdentifier: "com.example.Terminal", windowFrame: current))
        XCTAssertTrue(history.canUndo(applicationIdentifier: "com.example.Terminal"))
        XCTAssertFalse(history.canRedo(applicationIdentifier: "com.example.Terminal"))
    }

    func testRecordClearsRedoStackForThatApplicationOnly() {
        var history = WindowHistory()
        history.record(applicationIdentifier: "com.example.Terminal", frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        _ = history.undo(applicationIdentifier: "com.example.Terminal", currentFrame: CGRect(x: 10, y: 10, width: 100, height: 100))
        history.record(applicationIdentifier: "com.example.Terminal", frame: CGRect(x: 20, y: 20, width: 100, height: 100))

        XCTAssertFalse(history.canRedo(applicationIdentifier: "com.example.Terminal"))
    }

    func testHistoryIsIsolatedByApplicationIdentifier() {
        var history = WindowHistory()
        let terminalFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let browserFrame = CGRect(x: 200, y: 200, width: 500, height: 500)

        history.record(applicationIdentifier: "com.example.Terminal", frame: terminalFrame)
        history.record(applicationIdentifier: "com.example.Browser", frame: browserFrame)

        XCTAssertEqual(history.undo(applicationIdentifier: "com.example.Browser", currentFrame: .zero)?.windowFrame, browserFrame)
        XCTAssertEqual(history.undo(applicationIdentifier: "com.example.Terminal", currentFrame: .zero)?.windowFrame, terminalFrame)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowHistoryTests
```

Expected: command exits non-zero with compile errors containing `cannot find 'WindowHistory' in scope` and `cannot find 'WindowHistoryItem' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `/Users/woosublee/Documents/dev/zap/Sources/ZapCore/WindowHistory.swift`:

```swift
import CoreGraphics

public struct WindowHistoryItem: Equatable, Sendable {
    public let applicationIdentifier: String
    public let windowFrame: CGRect

    public init(applicationIdentifier: String, windowFrame: CGRect) {
        self.applicationIdentifier = applicationIdentifier
        self.windowFrame = windowFrame
    }
}

public struct WindowHistory: Equatable, Sendable {
    private var undoStacks: [String: [WindowHistoryItem]]
    private var redoStacks: [String: [WindowHistoryItem]]

    public init() {
        self.undoStacks = [:]
        self.redoStacks = [:]
    }

    public func canUndo(applicationIdentifier: String) -> Bool {
        !(undoStacks[applicationIdentifier]?.isEmpty ?? true)
    }

    public func canRedo(applicationIdentifier: String) -> Bool {
        !(redoStacks[applicationIdentifier]?.isEmpty ?? true)
    }

    public mutating func record(applicationIdentifier: String, frame: CGRect) {
        undoStacks[applicationIdentifier, default: []].append(WindowHistoryItem(
            applicationIdentifier: applicationIdentifier,
            windowFrame: frame
        ))
        redoStacks[applicationIdentifier] = []
    }

    public mutating func undo(applicationIdentifier: String, currentFrame: CGRect) -> WindowHistoryItem? {
        guard var stack = undoStacks[applicationIdentifier], let item = stack.popLast() else {
            return nil
        }

        undoStacks[applicationIdentifier] = stack
        redoStacks[applicationIdentifier, default: []].append(WindowHistoryItem(
            applicationIdentifier: applicationIdentifier,
            windowFrame: currentFrame
        ))
        return item
    }

    public mutating func redo(applicationIdentifier: String, currentFrame: CGRect) -> WindowHistoryItem? {
        guard var stack = redoStacks[applicationIdentifier], let item = stack.popLast() else {
            return nil
        }

        redoStacks[applicationIdentifier] = stack
        undoStacks[applicationIdentifier, default: []].append(WindowHistoryItem(
            applicationIdentifier: applicationIdentifier,
            windowFrame: currentFrame
        ))
        return item
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowHistoryTests
```

Expected: `WindowHistoryTests` passes.

- [ ] **Step 5: Run all ZapCore tests to verify the complete part passes**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap && swift test --filter ZapCoreTests
```

Expected: every existing and newly added `ZapCoreTests` test passes, including `NumberKeyTests`, `WindowActionTests`, `WindowShortcutTests`, `WindowShortcutDefaultsTests`, `ScreenDetectorTests`, `WindowPositionCalculatorTests`, and `WindowHistoryTests`.

- [ ] **Step 6: Commit**

```bash
cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowHistory.swift Tests/ZapCoreTests/WindowHistoryTests.swift && git commit -m "feat: add window history domain"
```

**실행 명령:**
- Fail 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowHistoryTests`
- Pass 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowHistoryTests`
- Full ZapCore 확인: `cd /Users/woosublee/Documents/dev/zap && swift test --filter ZapCoreTests`
- Commit: `cd /Users/woosublee/Documents/dev/zap && git add Sources/ZapCore/WindowHistory.swift Tests/ZapCoreTests/WindowHistoryTests.swift && git commit -m "feat: add window history domain"`

**예상 결과:** 첫 실행은 history 타입 미정의 compile failure이고, 구현 후 `WindowHistoryTests`와 전체 `ZapCoreTests`가 pass한다. Commit은 `WindowHistory`와 해당 테스트 파일만 포함한다.

---

## Part 2: Accessibility and window movement services

**Goal:** ZapApp에 Accessibility 권한 확인, System Settings 열기, frontmost window 조회와 frame 이동, window action 실행 조합 서비스를 추가한다.

**Architecture:** 실제 macOS Accessibility API는 concrete adapter 파일에만 둔다. `WindowManagementService`는 `AccessibilityPermissionChecking`, `SystemSettingsOpening`, `AccessibilityWindowControlling`, `ScreenProviding`, `WindowPositionCalculating`, `WindowHistoryRecording`, `FailureFeedback` 프로토콜만 의존하게 만들어 ZapAppTests에서 mock으로 모든 실패 경로를 검증한다.

**Test style:** `Tests/ZapAppTests/AppLauncherTests.swift`처럼 테스트 내부에 mock과 closure dependency를 두고, 호출되면 안 되는 dependency에는 `XCTFail`을 배치한다. 실제 AX 권한 prompt, `AXUIElement`, `NSWorkspace.shared.open`, `NSScreen.screens`, `NSSound.beep()`는 unit test에서 호출하지 않는다.

### Files

- Create: `Sources/ZapApp/Services/AccessibilityPermissionService.swift`
  - Defines `AccessibilityPermissionChecking`, `AXPermissionClienting`, `AccessibilityPermissionService`, `AXPermissionClient`.
  - Only `AXPermissionClient` calls `AXIsProcessTrusted()` and `AXIsProcessTrustedWithOptions(_:)`.
- Create: `Sources/ZapApp/Services/SystemSettingsOpener.swift`
  - Defines `SystemSettingsOpening` and `SystemSettingsOpener`.
  - Only `SystemSettingsOpener` calls `NSWorkspace.shared.open(_:)` with `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
- Create: `Sources/ZapApp/Services/AccessibilityWindowService.swift`
  - Defines `AccessibilityWindow`, `AccessibilityWindowError`, `AccessibilityWindowControlling`, `AXUIElementClienting`, `AccessibilityWindowService`, `AXUIElementClient`.
  - Only `AccessibilityWindowService` and `AXUIElementClient` call `AXUIElementCreateApplication(_:)`, `AXUIElementCopyAttributeValue`, `AXUIElementSetAttributeValue`, `AXValueCreate`, and `AXValueGetValue`.
  - Reads `kAXFocusedWindowAttribute`, `kAXRoleAttribute`, `kAXSubroleAttribute`, `kAXPositionAttribute`, `kAXSizeAttribute`.
  - Rejects `kAXSheetRole` and `kAXSystemDialogSubrole` through domain errors before any move is attempted.
- Create: `Sources/ZapApp/Services/WindowManagementService.swift`
  - Defines `WindowManagementService`, `WindowManagementResult`, `WindowManagementError`, `ScreenProviding`, `NSScreenProvider`, `WindowPositionCalculating`, `ZapCoreWindowPositionCalculatorAdapter`, `WindowHistoryRecording`, `FailureFeedback`.
  - Orchestrates permission check, focused window lookup, sheet/system dialog rejection, frame read, screen detection, pure calculation, `setFrame`, and success-only history recording.
- Modify: `Package.swift`
  - Add `.linkedFramework("ApplicationServices")` to the `ZapApp` target linker settings so AX symbols link consistently.
- Test: `Tests/ZapAppTests/AccessibilityPermissionServiceTests.swift`
- Test: `Tests/ZapAppTests/SystemSettingsOpenerTests.swift`
- Test: `Tests/ZapAppTests/AccessibilityWindowServiceTests.swift`
- Test: `Tests/ZapAppTests/WindowManagementServiceTests.swift`

### Protocol and mock boundaries

- [ ] **Step 1: Define test-facing protocols before concrete API wrappers**

  Add the following protocol shapes in the service files while writing implementation code:

  ```swift
  protocol AccessibilityPermissionChecking {
      var isTrusted: Bool { get }
      func requestPrompt()
  }

  protocol AXPermissionClienting {
      var isTrusted: Bool { get }
      func requestPrompt(showPrompt: Bool)
  }

  protocol SystemSettingsOpening {
      @discardableResult
      func openAccessibilitySettings() -> Bool
  }

  protocol AccessibilityWindowControlling {
      func frontmostWindow() throws -> AccessibilityWindow
      func frame(of window: AccessibilityWindow) throws -> CGRect
      func setFrame(_ frame: CGRect, of window: AccessibilityWindow) throws
  }

  protocol ScreenProviding {
      var displayFrames: [DisplayFrame] { get }
  }

  protocol WindowPositionCalculating {
      func calculate(_ input: WindowCalculationInput) -> WindowCalculationResult?
  }

  protocol WindowHistoryRecording: AnyObject {
      func recordSuccessfulMove(applicationIdentifier: String, previousFrame: CGRect, targetFrame: CGRect)
  }

  protocol FailureFeedback {
      func signalFailure()
  }
  ```

- [ ] **Step 2: Keep AX types out of service orchestration tests**

  `WindowManagementServiceTests` must instantiate only mock implementations of `AccessibilityPermissionChecking`, `AccessibilityWindowControlling`, `ScreenProviding`, `WindowPositionCalculating`, `WindowHistoryRecording`, and `FailureFeedback`. The tests must not import or construct `AXUIElement` values.

- [ ] **Step 3: Keep AX calls in the concrete window adapter**

  `AccessibilityWindowService` uses `AXUIElementClienting` for every raw AX call. `AccessibilityWindowServiceTests` use a mock `AXUIElementClienting` that returns stored attribute values and captures set operations. The concrete `AXUIElementClient` is the only implementation that touches `ApplicationServices` functions.

### Task 2.1: AccessibilityPermissionService and SystemSettingsOpener

**Files:**
- Create: `Sources/ZapApp/Services/AccessibilityPermissionService.swift`
- Create: `Sources/ZapApp/Services/SystemSettingsOpener.swift`
- Test: `Tests/ZapAppTests/AccessibilityPermissionServiceTests.swift`
- Test: `Tests/ZapAppTests/SystemSettingsOpenerTests.swift`

- [ ] **Step 1: Write failing permission service tests**

  Create `Tests/ZapAppTests/AccessibilityPermissionServiceTests.swift` with tests that capture the ZapAppTests closure/mock style:

  ```swift
  import XCTest
  @testable import ZapApp

  final class AccessibilityPermissionServiceTests: XCTestCase {
      func testIsTrustedDelegatesToAXPermissionClient() {
          let client = MockAXPermissionClient(isTrusted: true)
          let service = AccessibilityPermissionService(client: client)

          XCTAssertTrue(service.isTrusted)
      }

      func testRequestPromptAsksAXClientToShowPrompt() {
          let client = MockAXPermissionClient(isTrusted: false)
          let service = AccessibilityPermissionService(client: client)

          service.requestPrompt()

          XCTAssertEqual(client.requestedPromptValues, [true])
      }
  }

  private final class MockAXPermissionClient: AXPermissionClienting {
      var trusted: Bool
      var requestedPromptValues: [Bool] = []

      init(isTrusted: Bool) {
          self.trusted = isTrusted
      }

      var isTrusted: Bool {
          trusted
      }

      func requestPrompt(showPrompt: Bool) {
          requestedPromptValues.append(showPrompt)
      }
  }
  ```

- [ ] **Step 2: Run the permission tests and verify the expected failure**

  Run from `/Users/woosublee/Documents/dev/zap`:

  ```bash
  swift test --filter AccessibilityPermissionServiceTests
  ```

  Expected: FAIL with compile errors for missing `AccessibilityPermissionService` and `AXPermissionClienting`.

- [ ] **Step 3: Implement AccessibilityPermissionService with AX isolated in AXPermissionClient**

  Implement `Sources/ZapApp/Services/AccessibilityPermissionService.swift` so:

  - `AccessibilityPermissionService.isTrusted` returns `client.isTrusted`.
  - `AccessibilityPermissionService.requestPrompt()` calls `client.requestPrompt(showPrompt: true)`.
  - `AXPermissionClient.isTrusted` calls `AXIsProcessTrusted()`.
  - `AXPermissionClient.requestPrompt(showPrompt:)` calls `AXIsProcessTrustedWithOptions(_:)` with `kAXTrustedCheckOptionPrompt` set to the passed Boolean.

- [ ] **Step 4: Run the permission tests and verify pass**

  Run:

  ```bash
  swift test --filter AccessibilityPermissionServiceTests
  ```

  Expected: PASS for both tests.

- [ ] **Step 5: Write failing SystemSettingsOpener tests**

  Create `Tests/ZapAppTests/SystemSettingsOpenerTests.swift`:

  ```swift
  import XCTest
  @testable import ZapApp

  final class SystemSettingsOpenerTests: XCTestCase {
      func testOpenAccessibilitySettingsUsesAccessibilityPrivacyURL() {
          var capturedURL: URL?
          let opener = SystemSettingsOpener(openURL: { url in
              capturedURL = url
              return true
          })

          let didOpen = opener.openAccessibilitySettings()

          XCTAssertTrue(didOpen)
          XCTAssertEqual(capturedURL?.absoluteString, "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
      }

      func testOpenAccessibilitySettingsReturnsWorkspaceResult() {
          let opener = SystemSettingsOpener(openURL: { _ in false })

          XCTAssertFalse(opener.openAccessibilitySettings())
      }
  }
  ```

- [ ] **Step 6: Run the SystemSettingsOpener tests and verify the expected failure**

  Run:

  ```bash
  swift test --filter SystemSettingsOpenerTests
  ```

  Expected: FAIL with compile errors for missing `SystemSettingsOpener`.

- [ ] **Step 7: Implement SystemSettingsOpener with NSWorkspace isolated in the default closure**

  Implement `Sources/ZapApp/Services/SystemSettingsOpener.swift` so:

  - `SystemSettingsOpener.init(openURL:)` defaults to `{ NSWorkspace.shared.open($0) }`.
  - `openAccessibilitySettings()` builds exactly `URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")`.
  - The method returns the Boolean result from `openURL`.

- [ ] **Step 8: Run the permission and settings opener tests**

  Run:

  ```bash
  swift test --filter AccessibilityPermissionServiceTests
  swift test --filter SystemSettingsOpenerTests
  ```

  Expected: both commands PASS.

- [ ] **Step 9: Commit Part 2.1**

  Run:

  ```bash
  git add Package.swift Sources/ZapApp/Services/AccessibilityPermissionService.swift Sources/ZapApp/Services/SystemSettingsOpener.swift Tests/ZapAppTests/AccessibilityPermissionServiceTests.swift Tests/ZapAppTests/SystemSettingsOpenerTests.swift
  git commit -m "feat: add accessibility permission services"
  ```

### Task 2.2: AccessibilityWindowService

**Files:**
- Create: `Sources/ZapApp/Services/AccessibilityWindowService.swift`
- Test: `Tests/ZapAppTests/AccessibilityWindowServiceTests.swift`

- [ ] **Step 1: Write failing focused window and dialog classification tests**

  Create `Tests/ZapAppTests/AccessibilityWindowServiceTests.swift` with these cases:

  ```swift
  import CoreGraphics
  import XCTest
  @testable import ZapApp

  final class AccessibilityWindowServiceTests: XCTestCase {
      func testFrontmostWindowThrowsWhenFocusedWindowIsMissing() {
          let client = MockAXUIElementClient()
          client.frontmostProcessIdentifier = 42
          client.focusedWindowResult = .failure(.cannotComplete)
          let service = AccessibilityWindowService(client: client)

          XCTAssertThrowsError(try service.frontmostWindow()) { error in
              XCTAssertEqual(error as? AccessibilityWindowError, .focusedWindowMissing)
          }
      }

      func testFrontmostWindowMarksSheetAndSystemDialog() throws {
          let client = MockAXUIElementClient()
          client.frontmostProcessIdentifier = 42
          client.focusedWindowResult = .success(MockAXElement(id: "window-1"))
          client.stringAttributes["window-1:kAXRoleAttribute"] = "AXSheet"
          client.stringAttributes["window-1:kAXSubroleAttribute"] = "AXSystemDialog"
          let service = AccessibilityWindowService(client: client)

          let window = try service.frontmostWindow()

          XCTAssertTrue(window.isSheet)
          XCTAssertTrue(window.isSystemDialog)
      }
  }
  ```

  The mock may use test-only identifiers such as `MockAXElement(id:)`; it must conform to the `AXUIElementClienting` abstraction and must not call ApplicationServices.

- [ ] **Step 2: Run the focused window tests and verify the expected failure**

  Run:

  ```bash
  swift test --filter AccessibilityWindowServiceTests
  ```

  Expected: FAIL with compile errors for missing `AccessibilityWindowService`, `AccessibilityWindowError`, `AXUIElementClienting`, and mock-facing element abstractions.

- [ ] **Step 3: Implement frontmost window lookup and dialog metadata**

  Implement `AccessibilityWindowService.frontmostWindow()` so it performs this concrete sequence:

  1. Read the frontmost process identifier from the injected client.
  2. Create an application element for that process identifier.
  3. Copy `kAXFocusedWindowAttribute` from the application element.
  4. Copy `kAXRoleAttribute` and compare with `kAXSheetRole`.
  5. Copy `kAXSubroleAttribute` and compare with `kAXSystemDialogSubrole`.
  6. Return `AccessibilityWindow(applicationIdentifier:isSheet:isSystemDialog:storage:)`.
  7. Throw `.frontmostApplicationMissing` when no frontmost process identifier exists.
  8. Throw `.focusedWindowMissing` when `kAXFocusedWindowAttribute` cannot be read.

- [ ] **Step 4: Write failing frame read tests**

  Add tests for frame reading:

  ```swift
  func testFrameReadsPositionAndSizeAttributes() throws {
      let client = MockAXUIElementClient()
      let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
      client.cgPointAttributes["window-1:kAXPositionAttribute"] = CGPoint(x: 100, y: 200)
      client.cgSizeAttributes["window-1:kAXSizeAttribute"] = CGSize(width: 640, height: 480)
      let service = AccessibilityWindowService(client: client)

      let frame = try service.frame(of: window)

      XCTAssertEqual(frame, CGRect(x: 100, y: 200, width: 640, height: 480))
  }

  func testFrameThrowsWhenSizeAttributeFails() {
      let client = MockAXUIElementClient()
      let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
      client.cgPointAttributes["window-1:kAXPositionAttribute"] = CGPoint(x: 100, y: 200)
      client.sizeAttributeError = .failure
      let service = AccessibilityWindowService(client: client)

      XCTAssertThrowsError(try service.frame(of: window)) { error in
          XCTAssertEqual(error as? AccessibilityWindowError, .frameReadFailed(attribute: "kAXSizeAttribute"))
      }
  }
  ```

- [ ] **Step 5: Run frame read tests and verify the expected failure**

  Run:

  ```bash
  swift test --filter AccessibilityWindowServiceTests
  ```

  Expected: FAIL for missing or incomplete `frame(of:)` behavior.

- [ ] **Step 6: Implement frame read through kAXPositionAttribute and kAXSizeAttribute**

  Implement `frame(of:)` so it:

  - Reads `kAXPositionAttribute` as `CGPoint`.
  - Reads `kAXSizeAttribute` as `CGSize`.
  - Returns `CGRect(origin:size:)`.
  - Converts missing attributes, wrong AXValue types, and non-success `AXError` values into `AccessibilityWindowError.frameReadFailed(attribute:)`.

- [ ] **Step 7: Write failing setFrame tests including setFrame failure**

  Add tests for the Spectacle write order and failure mapping:

  ```swift
  func testSetFrameWritesSizeThenPositionThenSize() throws {
      let client = MockAXUIElementClient()
      let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
      let service = AccessibilityWindowService(client: client)

      try service.setFrame(CGRect(x: 20, y: 30, width: 800, height: 600), of: window)

      XCTAssertEqual(client.setOperations.map(\.attribute), ["kAXSizeAttribute", "kAXPositionAttribute", "kAXSizeAttribute"])
      XCTAssertEqual(client.setOperations[0].sizeValue, CGSize(width: 800, height: 600))
      XCTAssertEqual(client.setOperations[1].pointValue, CGPoint(x: 20, y: 30))
      XCTAssertEqual(client.setOperations[2].sizeValue, CGSize(width: 800, height: 600))
  }

  func testSetFrameThrowsWhenAXSetAttributeFails() {
      let client = MockAXUIElementClient()
      client.setAttributeError = .failure
      let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
      let service = AccessibilityWindowService(client: client)

      XCTAssertThrowsError(try service.setFrame(CGRect(x: 20, y: 30, width: 800, height: 600), of: window)) { error in
          XCTAssertEqual(error as? AccessibilityWindowError, .frameWriteFailed(attribute: "kAXSizeAttribute"))
      }
  }
  ```

- [ ] **Step 8: Run setFrame tests and verify the expected failure**

  Run:

  ```bash
  swift test --filter AccessibilityWindowServiceTests
  ```

  Expected: FAIL for missing or incomplete `setFrame(_:of:)` behavior.

- [ ] **Step 9: Implement setFrame through size-position-size AX writes**

  Implement `setFrame(_:of:)` so it:

  - Creates AX values for `CGSize` and `CGPoint`.
  - Writes `kAXSizeAttribute`, then `kAXPositionAttribute`, then `kAXSizeAttribute` again.
  - Throws `AccessibilityWindowError.frameWriteFailed(attribute:)` on the first failed write.
  - Releases created Core Foundation values after each operation has completed.

- [ ] **Step 10: Run all AccessibilityWindowService tests**

  Run:

  ```bash
  swift test --filter AccessibilityWindowServiceTests
  ```

  Expected: PASS for focused window 없음, sheet/system dialog metadata, frame read, and setFrame failure tests.

- [ ] **Step 11: Commit Part 2.2**

  Run:

  ```bash
  git add Sources/ZapApp/Services/AccessibilityWindowService.swift Tests/ZapAppTests/AccessibilityWindowServiceTests.swift
  git commit -m "feat: add accessibility window service"
  ```

### Task 2.3: WindowManagementService orchestration

**Files:**
- Create: `Sources/ZapApp/Services/WindowManagementService.swift`
- Test: `Tests/ZapAppTests/WindowManagementServiceTests.swift`

- [ ] **Step 1: Write failing permission denied test**

  Create `Tests/ZapAppTests/WindowManagementServiceTests.swift` with a test that asserts 권한 없음 stops the flow before focused window lookup:

  ```swift
  import CoreGraphics
  import XCTest
  @testable import ZapApp
  @testable import ZapCore

  final class WindowManagementServiceTests: XCTestCase {
      func testPerformFailsWithoutAccessibilityPermissionAndDoesNotRequestWindow() {
          let permission = MockAccessibilityPermission(isTrusted: false)
          let windows = MockAccessibilityWindows()
          windows.frontmostWindowHandler = {
              XCTFail("Window lookup must not run without Accessibility permission.")
              throw AccessibilityWindowError.focusedWindowMissing
          }
          let feedback = MockFailureFeedback()
          let service = makeService(permission: permission, windows: windows, feedback: feedback)

          let result = service.perform(action: .leftHalf)

          XCTAssertEqual(result, .failure(.accessibilityPermissionMissing))
          XCTAssertEqual(feedback.failureCount, 1)
          XCTAssertEqual(windows.frontmostWindowCallCount, 0)
      }
  }
  ```

- [ ] **Step 2: Run the permission denied test and verify the expected failure**

  Run:

  ```bash
  swift test --filter WindowManagementServiceTests/testPerformFailsWithoutAccessibilityPermissionAndDoesNotRequestWindow
  ```

  Expected: FAIL with compile errors for missing `WindowManagementService`, `WindowManagementResult`, `WindowManagementError`, and service dependency protocols.

- [ ] **Step 3: Implement the minimal WindowManagementService shell**

  Implement enough `WindowManagementService.perform(action:)` to:

  - Check `permission.isTrusted` first.
  - Return `.failure(.accessibilityPermissionMissing)` when false.
  - Call `feedback.signalFailure()` exactly once for that failure.
  - Avoid calling `windows.frontmostWindow()` in that branch.

- [ ] **Step 4: Run the permission denied test and verify pass**

  Run:

  ```bash
  swift test --filter WindowManagementServiceTests/testPerformFailsWithoutAccessibilityPermissionAndDoesNotRequestWindow
  ```

  Expected: PASS.

- [ ] **Step 5: Write failing focused window 없음 test**

  Add:

  ```swift
  func testPerformFailsWhenFocusedWindowIsMissing() {
      let windows = MockAccessibilityWindows()
      windows.frontmostWindowHandler = {
          throw AccessibilityWindowError.focusedWindowMissing
      }
      let calculator = MockWindowPositionCalculator()
      calculator.calculateHandler = { _ in
          XCTFail("Calculation must not run when there is no focused window.")
          return nil
      }
      let feedback = MockFailureFeedback()
      let service = makeService(windows: windows, calculator: calculator, feedback: feedback)

      let result = service.perform(action: .leftHalf)

      XCTAssertEqual(result, .failure(.focusedWindowMissing))
      XCTAssertEqual(feedback.failureCount, 1)
      XCTAssertEqual(calculator.calculateCallCount, 0)
  }
  ```

- [ ] **Step 6: Run the focused window 없음 test and verify the expected failure**

  Run:

  ```bash
  swift test --filter WindowManagementServiceTests/testPerformFailsWhenFocusedWindowIsMissing
  ```

  Expected: FAIL until `AccessibilityWindowError.focusedWindowMissing` maps to `WindowManagementError.focusedWindowMissing`.

- [ ] **Step 7: Implement focused window error mapping**

  Update `perform(action:)` so it:

  - Calls `windows.frontmostWindow()` after permission succeeds.
  - Maps `AccessibilityWindowError.focusedWindowMissing` to `.failure(.focusedWindowMissing)`.
  - Calls `feedback.signalFailure()` once.
  - Does not read frame, screens, calculator, history, or setFrame after the focused window failure.

- [ ] **Step 8: Write failing sheet/system dialog test**

  Add:

  ```swift
  func testPerformRejectsSheetAndSystemDialogBeforeCalculation() {
      let sheetWindow = AccessibilityWindow.mock(
          applicationIdentifier: "com.example.App",
          elementID: "sheet-1",
          isSheet: true,
          isSystemDialog: true
      )
      let windows = MockAccessibilityWindows(frontmostWindow: sheetWindow)
      let calculator = MockWindowPositionCalculator()
      calculator.calculateHandler = { _ in
          XCTFail("Calculation must not run for sheet/system dialog windows.")
          return nil
      }
      let feedback = MockFailureFeedback()
      let service = makeService(windows: windows, calculator: calculator, feedback: feedback)

      let result = service.perform(action: .fullscreen)

      XCTAssertEqual(result, .failure(.unsupportedWindow(.sheetOrSystemDialog)))
      XCTAssertEqual(feedback.failureCount, 1)
      XCTAssertEqual(windows.frameCallCount, 0)
      XCTAssertEqual(calculator.calculateCallCount, 0)
      XCTAssertEqual(windows.setFrameCallCount, 0)
  }
  ```

- [ ] **Step 9: Run the sheet/system dialog test and verify the expected failure**

  Run:

  ```bash
  swift test --filter WindowManagementServiceTests/testPerformRejectsSheetAndSystemDialogBeforeCalculation
  ```

  Expected: FAIL until `WindowManagementService` rejects `window.isSheet || window.isSystemDialog`.

- [ ] **Step 10: Implement sheet/system dialog rejection**

  Update `perform(action:)` so it:

  - Checks `window.isSheet || window.isSystemDialog` immediately after `frontmostWindow()`.
  - Returns `.failure(.unsupportedWindow(.sheetOrSystemDialog))`.
  - Calls `feedback.signalFailure()` once.
  - Does not read frame, calculate, record history, or set frame.

- [ ] **Step 11: Write failing calculation 실패 test**

  Add:

  ```swift
  func testPerformFailsWhenCalculationReturnsNil() {
      let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
      let windows = MockAccessibilityWindows(frontmostWindow: window)
      windows.frameResult = .success(CGRect(x: 100, y: 100, width: 500, height: 400))
      let screens = MockScreenProvider(displayFrames: [
          DisplayFrame(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875), isMain: true)
      ])
      let calculator = MockWindowPositionCalculator()
      calculator.calculateHandler = { _ in nil }
      let history = MockWindowHistoryRecorder()
      let feedback = MockFailureFeedback()
      let service = makeService(windows: windows, screens: screens, calculator: calculator, history: history, feedback: feedback)

      let result = service.perform(action: .leftHalf)

      XCTAssertEqual(result, .failure(.calculationFailed))
      XCTAssertEqual(feedback.failureCount, 1)
      XCTAssertEqual(windows.setFrameCallCount, 0)
      XCTAssertEqual(history.records.count, 0)
  }
  ```

- [ ] **Step 12: Run the calculation 실패 test and verify the expected failure**

  Run:

  ```bash
  swift test --filter WindowManagementServiceTests/testPerformFailsWhenCalculationReturnsNil
  ```

  Expected: FAIL until calculator nil maps to `.calculationFailed` and prevents `setFrame`.

- [ ] **Step 13: Implement screen and calculation path**

  Update `perform(action:)` so it:

  - Reads the current frame through `windows.frame(of:)`.
  - Reads displays through `screens.displayFrames`.
  - Uses the pure `ScreenDetector` to select source and destination visible frames.
  - Passes `WindowCalculationInput(windowFrame:sourceVisibleFrame:destinationVisibleFrame:action:)` to `calculator.calculate(_:)`.
  - Returns `.failure(.calculationFailed)` when the calculator returns nil.
  - Does not call `windows.setFrame` or `history.recordSuccessfulMove` for calculation failure.

- [ ] **Step 14: Write failing setFrame 실패 test**

  Add:

  ```swift
  func testPerformFailsWhenSetFrameFailsAndDoesNotRecordHistory() {
      let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
      let originalFrame = CGRect(x: 100, y: 100, width: 500, height: 400)
      let targetFrame = CGRect(x: 0, y: 25, width: 720, height: 875)
      let windows = MockAccessibilityWindows(frontmostWindow: window)
      windows.frameResult = .success(originalFrame)
      windows.setFrameResult = .failure(AccessibilityWindowError.frameWriteFailed(attribute: "kAXSizeAttribute"))
      let calculator = MockWindowPositionCalculator(result: WindowCalculationResult(frame: targetFrame, resolvedAction: .leftHalf))
      let history = MockWindowHistoryRecorder()
      let feedback = MockFailureFeedback()
      let service = makeService(windows: windows, calculator: calculator, history: history, feedback: feedback)

      let result = service.perform(action: .leftHalf)

      XCTAssertEqual(result, .failure(.setFrameFailed))
      XCTAssertEqual(feedback.failureCount, 1)
      XCTAssertEqual(windows.setFrameCallCount, 1)
      XCTAssertEqual(windows.capturedSetFrames, [targetFrame])
      XCTAssertEqual(history.records.count, 0)
  }
  ```

- [ ] **Step 15: Run the setFrame 실패 test and verify the expected failure**

  Run:

  ```bash
  swift test --filter WindowManagementServiceTests/testPerformFailsWhenSetFrameFailsAndDoesNotRecordHistory
  ```

  Expected: FAIL until `setFrame` errors map to `.setFrameFailed` and history recording is success-only.

- [ ] **Step 16: Implement setFrame failure handling**

  Update `perform(action:)` so it:

  - Calls `windows.setFrame(targetFrame, of: window)` after calculation succeeds.
  - Returns `.failure(.setFrameFailed)` when `setFrame` throws.
  - Calls `feedback.signalFailure()` once.
  - Does not call `history.recordSuccessfulMove` when `setFrame` throws.

- [ ] **Step 17: Write failing success-path test**

  Add:

  ```swift
  func testPerformSetsCalculatedFrameAndRecordsSuccessfulMove() {
      let window = AccessibilityWindow.mock(applicationIdentifier: "com.example.App", elementID: "window-1")
      let originalFrame = CGRect(x: 100, y: 100, width: 500, height: 400)
      let targetFrame = CGRect(x: 0, y: 25, width: 720, height: 875)
      let windows = MockAccessibilityWindows(frontmostWindow: window)
      windows.frameResult = .success(originalFrame)
      let calculator = MockWindowPositionCalculator(result: WindowCalculationResult(frame: targetFrame, resolvedAction: .leftHalf))
      let history = MockWindowHistoryRecorder()
      let feedback = MockFailureFeedback()
      let service = makeService(windows: windows, calculator: calculator, history: history, feedback: feedback)

      let result = service.perform(action: .leftHalf)

      XCTAssertEqual(result, .success(action: .leftHalf, frame: targetFrame))
      XCTAssertEqual(feedback.failureCount, 0)
      XCTAssertEqual(windows.capturedSetFrames, [targetFrame])
      XCTAssertEqual(history.records, [
          .init(applicationIdentifier: "com.example.App", previousFrame: originalFrame, targetFrame: targetFrame)
      ])
  }
  ```

- [ ] **Step 18: Run the success-path test and verify the expected failure**

  Run:

  ```bash
  swift test --filter WindowManagementServiceTests/testPerformSetsCalculatedFrameAndRecordsSuccessfulMove
  ```

  Expected: FAIL until `WindowManagementService` records history only after `setFrame` succeeds and returns success.

- [ ] **Step 19: Implement success path and adapters**

  Complete `WindowManagementService.swift` so it includes:

  - `NSScreenProvider.displayFrames` mapping every `NSScreen` to `DisplayFrame(frame:visibleFrame:isMain:)`.
  - `ZapCoreWindowPositionCalculatorAdapter.calculate(_:)` delegating to the pure `WindowPositionCalculator` from ZapCore.
  - `WindowManagementService.perform(action:)` returning `.success(action:result.frame)` after `setFrame` succeeds.
  - `history.recordSuccessfulMove(applicationIdentifier:previousFrame:targetFrame:)` after `setFrame` succeeds.
  - `feedback.signalFailure()` for every failure branch and never for success.

- [ ] **Step 20: Run all WindowManagementService tests**

  Run:

  ```bash
  swift test --filter WindowManagementServiceTests
  ```

  Expected: PASS for 권한 없음, focused window 없음, sheet/system dialog, calculation 실패, setFrame 실패, and success-path tests.

- [ ] **Step 21: Commit Part 2.3**

  Run:

  ```bash
  git add Sources/ZapApp/Services/WindowManagementService.swift Tests/ZapAppTests/WindowManagementServiceTests.swift
  git commit -m "feat: add window management service orchestration"
  ```

### Task 2.4: ZapAppTests integration run

**Files:**
- Test: `Tests/ZapAppTests/AccessibilityPermissionServiceTests.swift`
- Test: `Tests/ZapAppTests/SystemSettingsOpenerTests.swift`
- Test: `Tests/ZapAppTests/AccessibilityWindowServiceTests.swift`
- Test: `Tests/ZapAppTests/WindowManagementServiceTests.swift`
- Existing test reference: `Tests/ZapAppTests/AppLauncherTests.swift`

- [ ] **Step 1: Run the focused ZapApp service test set**

  Run:

  ```bash
  swift test --filter AccessibilityPermissionServiceTests
  swift test --filter SystemSettingsOpenerTests
  swift test --filter AccessibilityWindowServiceTests
  swift test --filter WindowManagementServiceTests
  ```

  Expected: all four commands PASS. No test opens System Settings, no test prompts for Accessibility permission, and no test moves a real window.

- [ ] **Step 2: Run the full ZapApp test bundle**

  Run:

  ```bash
  swift test --filter ZapAppTests
  ```

  Expected: PASS including the existing `AppLauncherTests` Finder activation test.

- [ ] **Step 3: Run the full package test suite**

  Run:

  ```bash
  swift test
  ```

  Expected: PASS for ZapCoreTests and ZapAppTests. The untracked `Sources/SnapApp`, `Sources/SnapCore`, `Tests/SnapAppTests`, and `Tests/SnapCoreTests` paths remain untouched.

- [ ] **Step 4: Commit Part 2 verification**

  Run:

  ```bash
  git status --short
  git commit --allow-empty -m "test: verify accessibility service plan part"
  ```

  Expected: the status output shows only files changed by Part 2 implementation work before the empty verification commit is created.

---

## Part 3: Global hotkey integration

**Goal:** Integrate Spectacle-style window action shortcuts into Zap's existing single `GlobalHotKeyService` registry while preserving Dock, Finder, and manual app shortcut behavior.

**Scope boundaries:** This part modifies hotkey registration and model wiring only. It does not implement window geometry calculation, Accessibility window movement, Settings UI rows, Sparkle behavior, release scripts, or Snap cleanup.

**Files:**
- Modify: `Sources/ZapApp/Services/GlobalHotKeyService.swift`
- Modify: `Sources/ZapApp/ViewModels/ZapAppModel.swift`
- Modify: `Sources/ZapApp/ViewModels/WindowManagementModel.swift`
- Test: `Tests/ZapAppTests/GlobalHotKeyRegistrationPlanTests.swift`
- Test: `Tests/ZapAppTests/GlobalHotKeyDispatchMappingTests.swift`
- Test: `Tests/ZapAppTests/ZapAppModelHotKeyIntegrationTests.swift`

---

### Task 3.1: Add pure hotkey registration planning for every shortcut domain

**Purpose:** Carbon `RegisterEventHotKey` is not deterministic in unit tests because it depends on process-level global OS state. Split registration planning into pure data mapping so tests can verify namespace allocation, conflict detection, and skipped disabled shortcuts without calling Carbon.

- [ ] **Step 1: Write failing tests for registration planning and conflict detection.**

  Create `Tests/ZapAppTests/GlobalHotKeyRegistrationPlanTests.swift` with XCTest coverage for these exact cases:
  - Finder hotkeys keep IDs `100`, `101`, `102`, `103` and option-only combos for physical `` ` ``/`₩` variants.
  - Dock hotkeys keep IDs `1...9` and use the selected Dock modifiers.
  - Manual shortcut hotkeys start at ID `1000` and map each registered manual hotkey ID back to its `ManualShortcut.id`.
  - Window shortcut hotkeys start at ID `2000` and map IDs to `WindowAction` in the input order of enabled, complete window shortcuts.
  - Disabled window shortcuts, nil `keyCode`, and empty modifiers are skipped.
  - A duplicate combo across Dock, Finder, manual, and window domains is detected through one shared `HotKeyCombo` set.
  - A window shortcut that conflicts with a previously planned shortcut is omitted and returns the error text `Some window shortcuts could not be registered: Fullscreen (conflict)`.
  - Existing Dock validation remains unchanged: an empty Dock modifier set returns `Select at least one modifier key.` and does not prevent eligible Finder, manual, or window shortcuts from being planned.

- [ ] **Step 2: Run the new planning tests and confirm red.**

  Run: `swift test --filter GlobalHotKeyRegistrationPlanTests`

  Expected: FAIL with compile errors for missing `GlobalHotKeyRegistrationPlanner`, missing `HotKeyRegistrationPlan`, or missing window shortcut arguments in the planned API.

- [ ] **Step 3: Add a pure registration planner inside `GlobalHotKeyService.swift`.**

  Add internal planning types in the same file so Carbon registration remains encapsulated:
  - `GlobalHotKeyRegistrationPlanner`
  - `HotKeyRegistrationPlan`
  - `PlannedHotKey`
  - `PlannedHotKeyOwner`
  - `HotKeyCombo`

  Required behavior:
  - Dock namespace: IDs `1...9`, owner `.dock(NumberKey)`.
  - Finder namespace: IDs `100...103`, owner `.finder`.
  - Manual namespace: IDs `1000 + index`, owner `.manual(UUID, name: String)`.
  - Window namespace: IDs `2000 + index`, owner `.window(WindowAction, title: String)`.
  - Preserve existing registration order: Finder, Dock, manual, window.
  - Insert every successfully planned combo into the same `Set<HotKeyCombo>` before planning the next domain.
  - Continue planning later domains after a conflict so unrelated shortcuts still register.
  - Convert `Set<ShortcutModifier>` to Carbon modifier flags through the existing `carbonModifiers(for:)` logic.
  - Keep the finder variant list identical to the current service: `kVK_ANSI_Grave`, `kVK_JIS_Yen`, `kVK_ANSI_Backslash`, `kVK_ISO_Section`.

- [ ] **Step 4: Run planning tests and confirm green.**

  Run: `swift test --filter GlobalHotKeyRegistrationPlanTests`

  Expected: PASS, with no Carbon hotkey registration calls made by the tests.

---

### Task 3.2: Register window shortcuts and dispatch window hotkey IDs

**Purpose:** Extend `GlobalHotKeyService` to register planned window action hotkeys through the same Carbon handler and invoke an `onWindowHotKey` callback when a window namespace ID is received.

- [ ] **Step 1: Write failing dispatch mapping tests.**

  Create `Tests/ZapAppTests/GlobalHotKeyDispatchMappingTests.swift` with XCTest coverage for these exact cases:
  - `dispatchHotKey(id: 2000)` invokes `onWindowHotKey(.center)` after a plan containing `.center` as the first window shortcut.
  - `dispatchHotKey(id: 2001)` invokes `onWindowHotKey(.fullscreen)` after a plan containing `.fullscreen` as the second window shortcut.
  - Finder IDs still invoke only `onFinderHotKey`.
  - Manual IDs still invoke only `onManualHotKey` with the stored `ManualShortcut.id`.
  - Dock IDs still invoke only `onDockHotKey` with the matching `NumberKey`.
  - Unknown IDs return without invoking any callback.

- [ ] **Step 2: Run dispatch mapping tests and confirm red.**

  Run: `swift test --filter GlobalHotKeyDispatchMappingTests`

  Expected: FAIL with compile errors for missing `onWindowHotKey`, missing `windowHotKeyIDs`, or missing test-only dispatch seam.

- [ ] **Step 3: Extend `GlobalHotKeyService` without changing existing callback semantics.**

  Implement these changes in `Sources/ZapApp/Services/GlobalHotKeyService.swift`:
  - Add `private let onWindowHotKey: (WindowAction) -> Void`.
  - Add `private var windowHotKeyIDs: [UInt32: WindowAction] = [:]`.
  - Add `onWindowHotKey` to the initializer after `onManualHotKey`.
  - Change `register` signature to:
    `func register(modifiers: Set<ShortcutModifier>, finderShortcutEnabled: Bool, manualShortcuts: [ManualShortcut], windowShortcuts: [WindowShortcut]) -> String?`
  - Inside `register`, call `GlobalHotKeyRegistrationPlanner.plan(...)` once, then call `RegisterEventHotKey` for each `PlannedHotKey` in the returned plan.
  - Populate `manualHotKeyIDs` from planned manual owners only after Carbon returns `noErr`.
  - Populate `windowHotKeyIDs` from planned window owners only after Carbon returns `noErr`.
  - Keep `hotKeyRefs.append(ref)` only when `status == noErr` and `ref` is non-nil.
  - Preserve existing error text for Finder, Dock, and manual registration failures.
  - Add window registration failure text `Some window shortcuts could not be registered: <Action Title> (<OSStatus>)` for Carbon failures and `<Action Title> (conflict)` for planner conflicts.
  - In `unregister`, clear both `manualHotKeyIDs` and `windowHotKeyIDs`.
  - In the event handler dispatch path, check Finder, manual, and window ID maps before falling back to Dock `NumberKey`.

- [ ] **Step 4: Isolate Carbon-free dispatch for tests.**

  Add an internal method that bypasses `EventRef` parsing but uses the same ID routing logic:
  - Signature: `@discardableResult internal func dispatchHotKey(id: UInt32) -> Bool`
  - Behavior: return `true` when a Dock, Finder, manual, or window callback is scheduled; return `false` for unknown IDs.
  - `handle(event:)` must call `dispatchHotKey(id: hotKeyID.id)` after validating the Carbon signature.
  - Tests call `dispatchHotKey(id:)`; production still receives IDs through Carbon.

- [ ] **Step 5: Run dispatch mapping tests and confirm green.**

  Run: `swift test --filter GlobalHotKeyDispatchMappingTests`

  Expected: PASS, proving ID routing without constructing Carbon `EventRef` values.

---

### Task 3.3: Connect `ZapAppModel` to `WindowManagementModel`

**Purpose:** Wire the new window hotkey callback into the app model so a window hotkey performs the matching `WindowAction`, and re-registration occurs when window shortcut configuration changes.

- [ ] **Step 1: Write failing model integration tests.**

  Create `Tests/ZapAppTests/ZapAppModelHotKeyIntegrationTests.swift` with XCTest coverage for these exact cases:
  - Initial `ZapAppModel` registration passes `selectedModifiers`, `isFinderShortcutEnabled`, `manualShortcuts`, and `windowManagementModel.windowShortcuts` to the hotkey service.
  - Triggering the captured Dock callback for `.one` still activates the first Dock item through `AppLaunching.activateOrLaunch`.
  - Triggering the captured Finder callback still calls `AppLaunching.activateFinder`.
  - Triggering the captured manual callback still activates the matching `ManualShortcut.dockItem`.
  - Triggering the captured window callback for `.leftHalf` calls `WindowManagementModel.perform(action: .leftHalf)` once and does not activate or launch an app.
  - Updating a window shortcut in `WindowManagementModel` triggers `ZapAppModel.registerHotKeys()` once with the new `windowShortcuts` array.
  - A hotkey registration error returned by the service is assigned to `ZapAppModel.registrationError`; a window model shortcut validation error remains in `WindowManagementModel.shortcutRegistrationError`.

- [ ] **Step 2: Run model integration tests and confirm red.**

  Run: `swift test --filter ZapAppModelHotKeyIntegrationTests`

  Expected: FAIL with compile errors because `ZapAppModel` does not expose window management wiring and `GlobalHotKeyService` has not accepted `windowShortcuts` in the app model call site.

- [ ] **Step 3: Add a testable hotkey service protocol.**

  In `GlobalHotKeyService.swift`, add an internal protocol:
  - `func register(modifiers: Set<ShortcutModifier>, finderShortcutEnabled: Bool, manualShortcuts: [ManualShortcut], windowShortcuts: [WindowShortcut]) -> String?`
  - `func unregister()`

  Make `GlobalHotKeyService` conform to this protocol. Use this protocol in `ZapAppModel` so tests can inject a capturing hotkey service without invoking Carbon.

- [ ] **Step 4: Add window management dependency injection to `ZapAppModel`.**

  Modify `Sources/ZapApp/ViewModels/ZapAppModel.swift` with these concrete wiring rules:
  - Add a stored `let windowManagementModel: WindowManagementModel` for Settings and menu use.
  - Add an initializer parameter `windowManagementModel: WindowManagementModel = WindowManagementModel()`.
  - Add an initializer parameter `hotKeyServiceFactory` that receives the four callbacks `(NumberKey) -> Void`, `() -> Void`, `(UUID) -> Void`, `(WindowAction) -> Void` and returns the hotkey service protocol.
  - Keep the default factory creating `GlobalHotKeyService(onDockHotKey:onFinderHotKey:onManualHotKey:onWindowHotKey:)`.
  - In the window callback, call `windowManagementModel.perform(action:)` on the main actor.
  - In `registerHotKeys()`, pass `windowManagementModel.windowShortcuts` as the fourth registration argument.
  - Set `windowManagementModel.onShortcutConfigurationChanged` to call `registerHotKeys()` after the model updates shortcut enablement, key code, display name, modifiers, or reset-to-defaults state.

- [ ] **Step 5: Preserve existing app shortcut behavior while adding the window callback.**

  Keep these existing methods unchanged except for dependency wiring around them:
  - `activateDockItem(for:)`
  - `activateFinder()`
  - `activateManualShortcut(id:)`
  - `activeManualShortcuts`
  - `shortcutTitle(for:)`
  - `finderShortcutTitle`

  The model tests from Step 1 must prove these behaviors still call the same `AppLaunching` methods after the fourth hotkey callback is introduced.

- [ ] **Step 6: Run model integration tests and confirm green.**

  Run: `swift test --filter ZapAppModelHotKeyIntegrationTests`

  Expected: PASS, including Dock, Finder, manual, and window callback assertions.

---

### Task 3.4: Preserve existing hotkey behavior with regression tests

**Purpose:** Ensure the unified registry does not regress current Zap behavior while adding window action shortcuts.

- [ ] **Step 1: Run existing baseline tests before final cleanup.**

  Run: `swift test --filter NumberKeyTests && swift test --filter AppLauncherTests`

  Expected: PASS. `NumberKeyTests` confirms Dock key-code mapping, and `AppLauncherTests` confirms Finder activation behavior.

- [ ] **Step 2: Add regression assertions to the new hotkey tests.**

  Extend `GlobalHotKeyRegistrationPlanTests` and `ZapAppModelHotKeyIntegrationTests` with these assertions:
  - Dock ID mapping remains `1...9` even when window shortcuts are enabled.
  - Finder ID mapping remains `100...103` even when window shortcuts are enabled.
  - Manual shortcut ID mapping remains `1000 + index` even when window shortcuts are enabled.
  - Window shortcut ID mapping starts at `2000`, never overlaps with Dock, Finder, or manual IDs, and is stable across repeated registration with the same `windowShortcuts` order.
  - A manual app shortcut and a window shortcut using the same key combo result in exactly one registered combo and one conflict error.

- [ ] **Step 3: Run focused regression tests.**

  Run: `swift test --filter GlobalHotKeyRegistrationPlanTests && swift test --filter GlobalHotKeyDispatchMappingTests && swift test --filter ZapAppModelHotKeyIntegrationTests`

  Expected: PASS, proving registration planning, ID dispatch, callback wiring, and preservation assertions all pass without directly testing Carbon.

- [ ] **Step 4: Run the complete suite.**

  Run: `swift test`

  Expected: PASS for `ZapCoreTests` and `ZapAppTests`. Existing Sparkle/update tests must remain green because this part does not change `Package.swift`, `UpdateService`, appcast generation, or release settings.

---

### Task 3.5: Manual verification for the Carbon boundary

**Purpose:** Unit tests prove planning and dispatch mapping; a short local app run verifies the real Carbon registration boundary.

- [ ] **Step 1: Launch Zap from the package.**

  Run: `swift run Zap`

  Expected: Zap launches as a menu bar app without a hotkey registration crash.

- [ ] **Step 2: Verify existing shortcuts still work.**

  While Zap is running:
  - Press `⌥1` through `⌥9` for populated Dock slots.
  - Press the Finder shortcut `⌥` + the available physical `` ` ``/`₩` key on the current keyboard layout.
  - Trigger one configured manual app shortcut.

  Expected: Dock shortcuts activate the matching Dock apps, Finder activation brings Finder windows forward, and the manual shortcut activates or launches its configured app.

- [ ] **Step 3: Verify a window shortcut reaches the window model boundary.**

  With Accessibility behavior implemented by the previous part, press one enabled window shortcut such as `⌥⌘F` for Fullscreen.

  Expected: The focused window action request reaches `WindowManagementModel.perform(action:)`; if Accessibility permission is missing, the model reports the permission path rather than launching an app or invoking Finder.

- [ ] **Step 4: Stop the app and rerun tests.**

  Run: `swift test`

  Expected: PASS after the manual run, showing no persistent UserDefaults or registration side effect broke the test suite.

---

## Part 4: Settings UI and final verification

**Goal:** Add the Window Management settings surface, reuse shortcut recording for window actions, keep the existing Dock/Finder/manual/Sparkle UI intact, and complete automated plus manual verification for the Zap window-management integration.

**Prerequisites from earlier parts:** `WindowAction`, `WindowShortcut`, `WindowShortcutDefaults`, `WindowManagementModel`, `AccessibilityPermissionService`, `WindowManagementService`, and window shortcut hotkey registration already exist with the method names from the design document.

**Files:**
- Modify: `Sources/ZapApp/Views/SettingsView.swift`
- Modify: `Sources/ZapApp/Views/ShortcutRecorderView.swift`
- Modify: `Sources/ZapApp/Views/MenuBarView.swift`
- Create: `Sources/ZapApp/Views/WindowManagementSettingsView.swift`
- Create: `Sources/ZapApp/Views/WindowShortcutRowView.swift`
- Test: `Tests/ZapAppTests/WindowManagementModelTests.swift`
- Test: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`
- Test: `Tests/ZapAppTests/MenuBarViewTests.swift`
- Test: `Tests/ZapAppTests/ShortcutRecorderViewTests.swift`

### Task 4.1: Lock the Settings-facing `WindowManagementModel` contract with tests

- [ ] **Step 1: Write failing tests for enable, disable, reset, and permission actions**

  Add these tests to `Tests/ZapAppTests/WindowManagementModelTests.swift`. If the file already exists from an earlier part, append the methods and reuse its fake services.

  ```swift
  @MainActor
  func testDisablingWindowManagementKeepsShortcutsButStopsActiveWindowHotkeys() {
      let registration = FakeWindowShortcutRegistration()
      let model = WindowManagementModel(
          permissionService: FakeAccessibilityPermissionService(isTrusted: true),
          windowService: FakeWindowManagementService(),
          shortcutRegistration: registration,
          shortcutStore: InMemoryWindowShortcutStore(shortcuts: WindowShortcutDefaults.shortcuts)
      )

      XCTAssertTrue(model.isWindowManagementEnabled)
      XCTAssertFalse(model.windowShortcuts.isEmpty)

      model.setWindowManagementEnabled(false)

      XCTAssertFalse(model.isWindowManagementEnabled)
      XCTAssertFalse(model.windowShortcuts.isEmpty)
      XCTAssertEqual(registration.lastRegisteredShortcuts, [])
  }

  @MainActor
  func testDisablingSingleWindowShortcutKeepsRecordedShortcutAndExcludesOnlyThatAction() throws {
      let registration = FakeWindowShortcutRegistration()
      let model = WindowManagementModel(
          permissionService: FakeAccessibilityPermissionService(isTrusted: true),
          windowService: FakeWindowManagementService(),
          shortcutRegistration: registration,
          shortcutStore: InMemoryWindowShortcutStore(shortcuts: WindowShortcutDefaults.shortcuts)
      )

      model.setShortcutEnabled(action: .leftHalf, isEnabled: false)

      let leftHalf = try XCTUnwrap(model.windowShortcuts.first { $0.action == .leftHalf })
      XCTAssertFalse(leftHalf.isEnabled)
      XCTAssertEqual(leftHalf.shortcutTitle, "⌥⌘←")
      XCTAssertFalse(registration.lastRegisteredShortcuts.contains { $0.action == .leftHalf })
      XCTAssertTrue(registration.lastRegisteredShortcuts.contains { $0.action == .rightHalf })
  }

  @MainActor
  func testResetWindowShortcutsRestoresSpectacleDefaultsAndEnablesActions() throws {
      let registration = FakeWindowShortcutRegistration()
      let model = WindowManagementModel(
          permissionService: FakeAccessibilityPermissionService(isTrusted: true),
          windowService: FakeWindowManagementService(),
          shortcutRegistration: registration,
          shortcutStore: InMemoryWindowShortcutStore(shortcuts: WindowShortcutDefaults.shortcuts)
      )

      model.setShortcut(action: .fullscreen, keyCode: 3, keyDisplayName: "3", modifiers: [.control])
      model.setShortcutEnabled(action: .fullscreen, isEnabled: false)

      model.resetShortcutsToDefaults()

      let fullscreen = try XCTUnwrap(model.windowShortcuts.first { $0.action == .fullscreen })
      XCTAssertTrue(fullscreen.isEnabled)
      XCTAssertEqual(fullscreen.shortcutTitle, "⌥⌘F")
      XCTAssertEqual(registration.lastRegisteredShortcuts.count, WindowAction.allCases.count)
  }

  @MainActor
  func testPermissionButtonsRequestPromptRefreshStateAndOpenSettings() {
      let permission = FakeAccessibilityPermissionService(isTrusted: false)
      let model = WindowManagementModel(
          permissionService: permission,
          windowService: FakeWindowManagementService(),
          shortcutRegistration: FakeWindowShortcutRegistration(),
          shortcutStore: InMemoryWindowShortcutStore(shortcuts: WindowShortcutDefaults.shortcuts)
      )

      XCTAssertFalse(model.accessibilityTrusted)

      model.requestAccessibilityPermission()
      XCTAssertEqual(permission.requestPromptCallCount, 1)

      permission.isTrusted = true
      model.refreshAccessibilityPermission()
      XCTAssertTrue(model.accessibilityTrusted)

      model.openAccessibilitySettings()
      XCTAssertEqual(permission.openSettingsCallCount, 1)
  }
  ```

- [ ] **Step 2: Run the model tests and verify the expected failure**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowManagementModelTests
  ```

  Expected before implementation: FAIL because at least one Settings-facing method is missing or does not update `lastRegisteredShortcuts`, persisted shortcuts, or permission state as asserted.

- [ ] **Step 3: Implement the minimal model behavior required by Settings**

  In `Sources/ZapApp/ViewModels/WindowManagementModel.swift`, expose these `@MainActor` methods and published properties for SwiftUI:

  ```swift
  @Published private(set) var windowShortcuts: [WindowShortcut]
  @Published private(set) var accessibilityTrusted: Bool
  @Published private(set) var windowManagementError: String?
  @Published var isWindowManagementEnabled: Bool

  func setWindowManagementEnabled(_ isEnabled: Bool)
  func setShortcut(action: WindowAction, keyCode: UInt32, keyDisplayName: String, modifiers: Set<ShortcutModifier>)
  func setShortcutEnabled(action: WindowAction, isEnabled: Bool)
  func resetShortcutsToDefaults()
  func requestAccessibilityPermission()
  func refreshAccessibilityPermission()
  func openAccessibilitySettings()
  ```

  Required behavior:
  - `setWindowManagementEnabled(false)` persists the disabled state, keeps stored shortcuts unchanged, and re-registers zero active window shortcuts.
  - `setShortcutEnabled(action:isEnabled:)` preserves `keyCode`, `keyDisplayName`, and `modifiers`, then re-registers enabled shortcuts only.
  - `resetShortcutsToDefaults()` replaces every action with `WindowShortcutDefaults.shortcuts`, enables all actions, persists the reset values, and re-registers active shortcuts.
  - `requestAccessibilityPermission()` calls the permission service prompt method once per button click.
  - `refreshAccessibilityPermission()` updates `accessibilityTrusted` from the permission service.
  - `openAccessibilitySettings()` opens the macOS Accessibility settings pane through the permission service or settings opener abstraction.

- [ ] **Step 4: Re-run the model tests and verify the pass**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter WindowManagementModelTests
  ```

  Expected after implementation: PASS for all `WindowManagementModelTests` methods.

### Task 4.2: Add `SettingsMode.windowManagement` without removing Automatic, Manual, Behavior, or Updates UI

- [ ] **Step 1: Write failing source-level UI wiring tests**

  Create `Tests/ZapAppTests/SettingsWindowManagementUITests.swift` with source-level assertions. SwiftUI rendering tests are brittle without adding a view inspection dependency, so these tests protect the concrete wiring that is most likely to regress.

  ```swift
  import XCTest

  final class SettingsWindowManagementUITests: XCTestCase {
      private var packageRootURL: URL {
          URL(fileURLWithPath: #filePath)
              .deletingLastPathComponent()
              .deletingLastPathComponent()
              .deletingLastPathComponent()
      }

      func testSettingsModeIncludesWindowManagementAndKeepsExistingModes() throws {
          let source = try String(contentsOf: packageRootURL
              .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

          XCTAssertTrue(source.contains("case automatic"))
          XCTAssertTrue(source.contains("case manual"))
          XCTAssertTrue(source.contains("case windowManagement"))
          XCTAssertTrue(source.contains("Window Management"))
          XCTAssertTrue(source.contains("WindowManagementSettingsView"))
      }

      func testSettingsStillContainsBehaviorAndSparkleUpdateControls() throws {
          let source = try String(contentsOf: packageRootURL
              .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

          XCTAssertTrue(source.contains("Section(\"Behavior\")"))
          XCTAssertTrue(source.contains("Launch at login"))
          XCTAssertTrue(source.contains("Show menu bar icon"))
          XCTAssertTrue(source.contains("Section(\"Updates\")"))
          XCTAssertTrue(source.contains("Automatically check for updates"))
          XCTAssertTrue(source.contains("Check for Updates Now"))
          XCTAssertTrue(source.contains("Updates are delivered with Sparkle"))
      }

      func testAutomaticAndManualShortcutControlsRemainWired() throws {
          let source = try String(contentsOf: packageRootURL
              .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

          XCTAssertTrue(source.contains("automaticShortcutsSection"))
          XCTAssertTrue(source.contains("Finder shortcut"))
          XCTAssertTrue(source.contains("Dock app shortcuts"))
          XCTAssertTrue(source.contains("manualSection"))
          XCTAssertTrue(source.contains("ManualShortcutRow"))
          XCTAssertTrue(source.contains("Add App Shortcut"))
      }
  }
  ```

- [ ] **Step 2: Run the Settings UI wiring tests and verify the expected failure**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter SettingsWindowManagementUITests
  ```

  Expected before implementation: FAIL because `SettingsView.swift` does not contain `case windowManagement` or `WindowManagementSettingsView`.

- [ ] **Step 3: Add the third Settings mode and route it to the new view**

  Modify `Sources/ZapApp/Views/SettingsView.swift`:
  - Add `case windowManagement` to `SettingsMode`.
  - Return `"Window Management"` from `SettingsMode.title` for that case.
  - Add `@ObservedObject var windowManagementModel: WindowManagementModel` to `SettingsView` and update all call sites that construct `SettingsView`.
  - Replace the two-branch body with a `switch selectedMode` so `.automatic`, `.manual`, and `.windowManagement` are explicit.
  - Keep `behaviorSection` and `updatesSection` outside the mode switch so Launch at login, Show menu bar icon, and Sparkle controls remain visible in every mode.

  Required routing shape:

  ```swift
  switch selectedMode {
  case .automatic:
      automaticShortcutsSection
      automaticSection
  case .manual:
      manualSection
  case .windowManagement:
      WindowManagementSettingsView(model: windowManagementModel)
  }

  behaviorSection
  updatesSection
  ```

- [ ] **Step 4: Re-run the Settings UI wiring tests and verify the pass**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter SettingsWindowManagementUITests
  ```

  Expected after implementation: PASS, with Automatic, Manual, Window Management, Behavior, and Updates strings all present.

### Task 4.3: Create `WindowManagementSettingsView` with permission UI, global enable, reset, and rows

- [ ] **Step 1: Write failing tests for the new view source contract**

  Extend `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`:

  ```swift
  func testWindowManagementSettingsViewContainsPermissionEnableResetAndShortcutRows() throws {
      let source = try String(contentsOf: packageRootURL
          .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

      XCTAssertTrue(source.contains("Accessibility Permission"))
      XCTAssertTrue(source.contains("Open Accessibility Settings"))
      XCTAssertTrue(source.contains("Refresh Permission"))
      XCTAssertTrue(source.contains("Enable window management shortcuts"))
      XCTAssertTrue(source.contains("Reset to Defaults"))
      XCTAssertTrue(source.contains("WindowShortcutRowView"))
      XCTAssertTrue(source.contains("ForEach(model.windowShortcuts"))
  }
  ```

- [ ] **Step 2: Run the view source contract test and verify the expected failure**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter SettingsWindowManagementUITests/testWindowManagementSettingsViewContainsPermissionEnableResetAndShortcutRows
  ```

  Expected before implementation: FAIL because `Sources/ZapApp/Views/WindowManagementSettingsView.swift` does not exist.

- [ ] **Step 3: Implement `WindowManagementSettingsView`**

  Create `Sources/ZapApp/Views/WindowManagementSettingsView.swift` with these sections:
  - Header text: `Manage shortcuts for moving and resizing the frontmost window.`
  - `Accessibility Permission` section:
    - If `model.accessibilityTrusted` is true, show `Accessibility permission granted.` with a green checkmark.
    - If false, show `Zap needs Accessibility permission to move and resize windows.` with warning styling.
    - Provide `Open Accessibility Settings`, `Refresh Permission`, and `Request Permission` buttons wired to `model.openAccessibilitySettings()`, `model.refreshAccessibilityPermission()`, and `model.requestAccessibilityPermission()`.
  - `Shortcuts` section:
    - Toggle label: `Enable window management shortcuts`, bound to `model.isWindowManagementEnabled` through `model.setWindowManagementEnabled(_:)`.
    - Button label: `Reset to Defaults`, calling `model.resetShortcutsToDefaults()`.
    - `ForEach(model.windowShortcuts)` creates `WindowShortcutRowView` for every action.
    - If `model.windowManagementError` is non-nil, show it as orange caption text.

- [ ] **Step 4: Re-run the view source contract test and verify the pass**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter SettingsWindowManagementUITests/testWindowManagementSettingsViewContainsPermissionEnableResetAndShortcutRows
  ```

  Expected after implementation: PASS.

### Task 4.4: Create `WindowShortcutRowView` and reuse `ShortcutRecorderView`

- [ ] **Step 1: Write failing tests for row and recorder reuse**

  Create `Tests/ZapAppTests/ShortcutRecorderViewTests.swift`:

  ```swift
  import XCTest

  final class ShortcutRecorderViewTests: XCTestCase {
      private var packageRootURL: URL {
          URL(fileURLWithPath: #filePath)
              .deletingLastPathComponent()
              .deletingLastPathComponent()
              .deletingLastPathComponent()
      }

      func testShortcutRecorderSupportsAppAndWindowActionCopy() throws {
          let source = try String(contentsOf: packageRootURL
              .appendingPathComponent("Sources/ZapApp/Views/ShortcutRecorderView.swift"))

          XCTAssertTrue(source.contains("Record App Shortcut"))
          XCTAssertTrue(source.contains("Record Window Shortcut"))
          XCTAssertTrue(source.contains("Press the global shortcut that opens"))
          XCTAssertTrue(source.contains("Press the global shortcut that runs"))
          XCTAssertTrue(source.contains("Select at least one modifier key."))
      }

      func testWindowShortcutRowUsesRecorderAndSupportsEnableDisable() throws {
          let source = try String(contentsOf: packageRootURL
              .appendingPathComponent("Sources/ZapApp/Views/WindowShortcutRowView.swift"))

          XCTAssertTrue(source.contains("ShortcutRecorderView"))
          XCTAssertTrue(source.contains("Record"))
          XCTAssertTrue(source.contains("Toggle"))
          XCTAssertTrue(source.contains("setEnabled"))
          XCTAssertTrue(source.contains("shortcut.shortcutTitle ?? \"Not set\""))
      }
  }
  ```

- [ ] **Step 2: Run the recorder tests and verify the expected failure**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter ShortcutRecorderViewTests
  ```

  Expected before implementation: FAIL because the recorder still has app-only copy and `WindowShortcutRowView.swift` does not exist.

- [ ] **Step 3: Improve `ShortcutRecorderView` copy while preserving manual app shortcut behavior**

  Modify `Sources/ZapApp/Views/ShortcutRecorderView.swift`:
  - Replace the stored `appName` text dependency with stored `title`, `instructions`, and `capturePrompt` strings.
  - Keep an app initializer so `SettingsView` manual shortcuts continue calling `ShortcutRecorderView(appName:onRecord:onCancel:)`.
  - Add a window-action initializer so `WindowShortcutRowView` can call `ShortcutRecorderView(windowActionName:onRecord:onCancel:)`.
  - Keep the existing no-modifier validation text: `Select at least one modifier key.`

  Required initializer behavior:

  ```swift
  init(appName: String, onRecord: @escaping (RecordedShortcut) -> Void, onCancel: @escaping () -> Void) {
      self.title = "Record App Shortcut"
      self.instructions = "Press the global shortcut that opens \(appName)."
      self.capturePrompt = "Press app shortcut"
      self.onRecord = onRecord
      self.onCancel = onCancel
  }

  init(windowActionName: String, onRecord: @escaping (RecordedShortcut) -> Void, onCancel: @escaping () -> Void) {
      self.title = "Record Window Shortcut"
      self.instructions = "Press the global shortcut that runs \(windowActionName)."
      self.capturePrompt = "Press window shortcut"
      self.onRecord = onRecord
      self.onCancel = onCancel
  }
  ```

- [ ] **Step 4: Implement `WindowShortcutRowView`**

  Create `Sources/ZapApp/Views/WindowShortcutRowView.swift` with:
  - Action display name from `shortcut.action.title`.
  - Shortcut text `shortcut.shortcutTitle ?? "Not set"` in a monospaced font.
  - A row toggle bound to `shortcut.isEnabled`; disable the toggle when `shortcut.shortcutTitle == nil`.
  - A `Record` button that opens `ShortcutRecorderView(windowActionName:onRecord:onCancel:)`.
  - On record, call `record(recordedShortcut)` with the `RecordedShortcut` from the recorder.
  - A short description text for destructive behavior is not needed because reset is handled at the parent view.

  Required row initializer:

  ```swift
  struct WindowShortcutRowView: View {
      let shortcut: WindowShortcut
      let setEnabled: (Bool) -> Void
      let record: (RecordedShortcut) -> Void
  }
  ```

- [ ] **Step 5: Re-run the recorder tests and verify the pass**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter ShortcutRecorderViewTests
  ```

  Expected after implementation: PASS.

### Task 4.5: Decide and verify `MenuBarView` behavior for window management

- [ ] **Step 1: Write failing tests for menu bar visibility policy**

  Create `Tests/ZapAppTests/MenuBarViewTests.swift` if it does not exist, or append these tests if the file exists.

  ```swift
  import XCTest

  final class MenuBarViewTests: XCTestCase {
      private var packageRootURL: URL {
          URL(fileURLWithPath: #filePath)
              .deletingLastPathComponent()
              .deletingLastPathComponent()
              .deletingLastPathComponent()
      }

      func testMenuBarKeepsDockFinderManualRowsAndSettingsUpdateActions() throws {
          let source = try String(contentsOf: packageRootURL
              .appendingPathComponent("Sources/ZapApp/Views/MenuBarView.swift"))

          XCTAssertTrue(source.contains("Finder"))
          XCTAssertTrue(source.contains("activeManualShortcuts"))
          XCTAssertTrue(source.contains("NumberKey.allCases"))
          XCTAssertTrue(source.contains("Refresh Dock Apps"))
          XCTAssertTrue(source.contains("Settings..."))
          XCTAssertTrue(source.contains("Check for Updates..."))
          XCTAssertTrue(source.contains("Quit"))
      }

      func testMenuBarDoesNotListEveryWindowActionShortcut() throws {
          let source = try String(contentsOf: packageRootURL
              .appendingPathComponent("Sources/ZapApp/Views/MenuBarView.swift"))

          XCTAssertFalse(source.contains("ForEach(model.windowManagementModel.windowShortcuts"))
          XCTAssertFalse(source.contains("ForEach(model.windowShortcuts"))
      }
  }
  ```

- [ ] **Step 2: Run the menu bar tests and verify the expected failure or current pass**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter MenuBarViewTests
  ```

  Expected before implementation: PASS if `MenuBarView` is still unchanged, or FAIL if previous work added a full window-action list.

- [ ] **Step 3: Keep `MenuBarView` focused on app-launch shortcuts**

  Implement this visibility policy in `Sources/ZapApp/Views/MenuBarView.swift`:
  - Keep Finder, manual app shortcuts, and Dock slots visible exactly as they are.
  - Keep Settings, Check for Updates, About, and Quit actions visible exactly as they are.
  - Do not list all 18 window actions in the menu bar because the Settings window is the editing surface for those shortcuts.
  - If window-management registration or permission state must be surfaced in the menu bar, show at most one compact warning row above `shortcutList`, using the same orange caption style as the existing registration error block.
  - Keep the existing `Show menu bar icon` setting in `SettingsView` as the only control for whether the menu bar icon itself is shown.

- [ ] **Step 4: Re-run the menu bar tests and verify the pass**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter MenuBarViewTests
  ```

  Expected after implementation: PASS, and `MenuBarView` does not contain a `ForEach` over window action shortcuts.

### Task 4.6: Verify existing Sparkle/update UI and Dock/Finder/manual UI are preserved

- [ ] **Step 1: Run the existing Sparkle/update tests**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter UpdateServiceTests
  ```

  Expected: PASS. These tests confirm local builds do not auto-start Sparkle checks, release builds do start checks, manual update checks still work, and `SettingsWindowPresenter` does not create a temporary `UpdateService`.

- [ ] **Step 2: Run existing update metadata tests**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter UpdateMetadataTests
  ```

  Expected: PASS. This confirms the release metadata and Sparkle-related assumptions used by the existing update flow still hold.

- [ ] **Step 3: Run existing Dock/Finder/manual app behavior tests**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test --filter AppLauncherTests
  cd /Users/woosublee/Documents/dev/zap && swift test --filter NumberKeyTests
  ```

  Expected: PASS. `AppLauncherTests` covers app activation/launch behavior, and `NumberKeyTests` confirms Dock number key mapping remains stable.

- [ ] **Step 4: Run a concrete source preservation check for Settings and menu labels**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && python3 - <<'PY'
  from pathlib import Path
  settings = Path("Sources/ZapApp/Views/SettingsView.swift").read_text()
  menu = Path("Sources/ZapApp/Views/MenuBarView.swift").read_text()
  required_settings = [
      'Section("Updates")',
      'Automatically check for updates',
      'Check for Updates Now',
      'Updates are delivered with Sparkle',
      'Section("Behavior")',
      'Launch at login',
      'Show menu bar icon',
      'Finder shortcut',
      'Dock app shortcuts',
      'Manual App Shortcuts',
      'Add App Shortcut'
  ]
  required_menu = [
      'Refresh Dock Apps',
      'Settings...',
      'Check for Updates...',
      'activeManualShortcuts',
      'NumberKey.allCases',
      'Finder'
  ]
  missing_settings = [item for item in required_settings if item not in settings]
  missing_menu = [item for item in required_menu if item not in menu]
  assert not missing_settings, f"Settings labels missing: {missing_settings}"
  assert not missing_menu, f"Menu labels missing: {missing_menu}"
  PY
  ```

  Expected: exit code 0 with no output.

- [ ] **Step 5: Check release-critical files for accidental Spectacle/Spectra drift**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && python3 - <<'PY'
  from pathlib import Path
  files = [Path("Info.plist"), Path("Package.swift"), Path("Makefile")]
  joined = "\n".join(path.read_text(errors="ignore") for path in files if path.exists())
  forbidden = ["Spectacle", "Spectra", "com.divisiblebyzero.Spectacle", "spectacleapp.com"]
  hits = [word for word in forbidden if word in joined]
  assert not hits, f"Release files contain imported Spectacle/Spectra identifiers: {hits}"
  assert "https://github.com/sparkle-project/Sparkle" in Path("Package.swift").read_text()
  PY
  ```

  Expected: exit code 0 with no output. `Package.swift` may include an added `ApplicationServices` framework from the accessibility part, but it must keep the Sparkle dependency and must not import Spectacle/Spectra identifiers.

### Task 4.7: Run full automated verification

- [ ] **Step 1: Run all tests**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift test
  ```

  Expected: PASS for `ZapCoreTests` and `ZapAppTests`, including the new model, settings source, shortcut recorder, and menu bar tests.

- [ ] **Step 2: Check the working tree only contains planned implementation files**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && git status --short
  ```

  Expected: changed files are limited to the planned Zap source/test files for window management. Existing untracked `Sources/SnapApp/`, `Sources/SnapCore/`, `Tests/SnapAppTests/`, and `Tests/SnapCoreTests/` may still appear from the rename residue described in the design document and must not be deleted as part of this work.

- [ ] **Step 3: Review release-sensitive diffs**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && git diff -- Info.plist Makefile Package.swift Sources/ZapApp/Views/SettingsView.swift Sources/ZapApp/Views/MenuBarView.swift Sources/ZapApp/Views/ShortcutRecorderView.swift
  ```

  Expected:
  - `SettingsView.swift` adds Window Management mode while retaining Behavior and Updates sections.
  - `MenuBarView.swift` keeps Dock/Finder/manual rows and update/settings actions.
  - `ShortcutRecorderView.swift` supports app and window-action copy without weakening modifier validation.
  - `Info.plist` and `Makefile` have no Spectacle/Spectra rename, appcast, bundle identifier, or signing drift.
  - `Package.swift` keeps Sparkle at the existing exact dependency version and only includes framework additions required by previous accessibility implementation.

### Task 4.8: Manual verification checklist for UI and macOS Accessibility behavior

SwiftUI UI automation and Accessibility window movement are not reliable in headless SwiftPM tests, so complete this manual checklist after `swift test` passes.

- [ ] **Step 1: Launch Zap locally**

  Run:

  ```bash
  cd /Users/woosublee/Documents/dev/zap && swift run Zap
  ```

  Expected: Zap launches as a menu bar app without changing the app name, update menu labels, or menu bar icon behavior.

- [ ] **Step 2: Verify Settings mode navigation**

  Manual checks:
  - Open Settings from the menu bar.
  - Confirm segmented modes include `Automatic`, `Manual`, and `Window Management`.
  - Switch to `Automatic` and confirm Dock app shortcuts, Finder shortcut toggle, refresh button, Behavior section, and Updates section are visible.
  - Switch to `Manual` and confirm Add App Shortcut, manual rows, Behavior section, and Updates section are visible.
  - Switch to `Window Management` and confirm Accessibility Permission, Enable window management shortcuts, Reset to Defaults, and one row for every `WindowAction` are visible.

- [ ] **Step 3: Verify shortcut recording copy and validation**

  Manual checks:
  - In Manual mode, click `Record` for an app shortcut and confirm the sheet title is `Record App Shortcut`.
  - Press a key without modifier and confirm `Select at least one modifier key.` appears.
  - In Window Management mode, click `Record` for `Left Half` and confirm the sheet title is `Record Window Shortcut` and the instructions mention running `Left Half`.
  - Record `⌥⌘←` and confirm the row displays `⌥⌘←`.

- [ ] **Step 4: Verify enable, disable, and reset behavior**

  Manual checks:
  - Disable `Left Half`; confirm the row remains visible and still displays its shortcut.
  - Press the disabled `Left Half` shortcut; expected result is no window move from that shortcut.
  - Re-enable `Left Half`; press the shortcut again; expected result is the frontmost window moves to the left half when Accessibility permission is granted.
  - Change `Fullscreen` to another modified key combo, then click `Reset to Defaults`; expected result is `Fullscreen` returns to `⌥⌘F` and disabled rows become enabled.
  - Turn off `Enable window management shortcuts`; expected result is window action shortcuts stop triggering while Dock/Finder/manual app shortcuts continue to trigger.

- [ ] **Step 5: Verify Accessibility permission UI**

  Manual checks:
  - With Accessibility permission not granted, confirm Window Management mode shows `Zap needs Accessibility permission to move and resize windows.`
  - Click `Request Permission`; expected result is macOS displays the Accessibility permission prompt when TCC allows prompting.
  - Click `Open Accessibility Settings`; expected result is System Settings opens to Privacy & Security Accessibility.
  - Grant permission for Zap, return to Settings, and click `Refresh Permission`; expected result is `Accessibility permission granted.`

- [ ] **Step 6: Verify window actions on real apps**

  Manual checks after permission is granted:
  - In Finder, Chrome or Safari, Terminal, Notes, and one additional resizable app, verify Center, Fullscreen, Left Half, Right Half, Top Half, Bottom Half, all four corners, Next Third, Previous Third, Larger, Smaller, Undo, and Redo.
  - On a multi-display setup, verify Next Display and Previous Display move the frontmost window between displays using the visible frame on the destination display.
  - On Terminal or iTerm, confirm Larger and Smaller produce a best-effort size change even if the app snaps to its text grid.

- [ ] **Step 7: Verify existing Zap behavior after window-management changes**

  Manual checks:
  - Press Dock shortcuts `⌥1` through `⌥9`; expected result is mapped Dock apps launch or activate as before.
  - Press the Finder shortcut for the active keyboard layout variant; expected result is Finder activates.
  - Add a manual app shortcut, record a modified key combo, trigger it, disable it, re-enable it, and remove it; expected result is the manual flow behaves as before.
  - In Settings Updates, toggle `Automatically check for updates` and click `Check for Updates Now`; expected result is the existing Sparkle update UI appears or reports no update without local-build auto scheduling.
  - Toggle `Show menu bar icon`; expected result is the menu bar icon visibility follows the existing activation policy.

### Task 4.9: Final acceptance criteria

- [ ] `SettingsMode.windowManagement` exists and `SettingsView` routes it to `WindowManagementSettingsView`.
- [ ] `WindowManagementSettingsView` shows permission status/actions, global enable, reset, registration/error copy, and a row for every window action.
- [ ] `WindowShortcutRowView` supports per-action enable/disable and recording through the reused `ShortcutRecorderView`.
- [ ] `ShortcutRecorderView` has distinct app shortcut and window shortcut wording while preserving modifier validation.
- [ ] `MenuBarView` keeps Dock/Finder/manual rows and does not list every window action shortcut.
- [ ] Existing Behavior and Sparkle Updates settings remain visible in all Settings modes.
- [ ] ViewModel tests cover UI behavior that SwiftUI automation cannot reliably verify.
- [ ] Manual verification covers Accessibility permission UI, real window movement, multi-display movement, undo/redo, Dock/Finder/manual shortcuts, Sparkle update UI, and menu bar icon visibility.
- [ ] `swift test` passes from `/Users/woosublee/Documents/dev/zap`.
