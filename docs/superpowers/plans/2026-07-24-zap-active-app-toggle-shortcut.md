# Zap Active App Toggle Shortcut Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사용자가 설정한 글로벌 단축키로 현재 활성 앱의 Zap 단축키를 비활성화하거나 다시 활성화하며, 앱별 disabled 상태에서는 제어 단축키만 유지하고 전역 Pause 상태에서는 모든 단축키를 해제한다.

**Architecture:** 새 `ActiveApplicationToggleShortcut` Codable 모델을 `ZapAppModel`이 소유하고 전용 `UserDefaults` JSON 키로 저장한다. 기존 `GlobalHotKeyRegistrationPlanner`에 최고 우선순위 owner와 `.activeApplicationToggleOnly` scope를 추가하고, 기존 `GlobalHotKeyService`가 동일한 Carbon handler에서 ID `3000`을 dispatch한다. `SettingsView`는 General의 Permissions와 Behavior 사이에 `Shortcut Controls` 카드를 추가하고 기존 keycap 및 recorder 컴포넌트를 재사용한다.

**Tech Stack:** Swift 5.10, SwiftUI, AppKit, Carbon `RegisterEventHotKey`, Foundation `UserDefaults`/`Codable`, XCTest, Swift Package Manager, macOS 13+

## Global Constraints

- 기준 설계 문서: `/Users/woosublee/Documents/dev/zap/docs/superpowers/specs/2026-07-24-zap-active-app-toggle-shortcut-design.md`
- 구현 기준 브랜치의 현재 HEAD는 `80c0f64 feat: add menu bar shortcut pausing`이다.
- `GlobalHotKeyRegistrationPlanner`와 `GlobalHotKeyService`를 계속 단일 통합 registry로 사용한다.
- 새 sidebar mode, 별도 Settings 페이지, 별도 hotkey service를 만들지 않는다.
- 제어 단축키 기본값은 반드시 미설정이어야 하며 기본 키 조합을 제공하지 않는다.
- 별도의 enable toggle을 추가하지 않는다. 단축키 존재 여부가 활성 상태이며 `Clear`가 비활성화 동작이다.
- 제어 owner `.activeApplicationToggle`은 Finder, Dock, Manual, Window보다 먼저 조합을 예약한다.
- 현재 앱이 disabled이면 `.activeApplicationToggleOnly` scope로 제어 단축키만 등록한다.
- 전역 Pause가 활성화되면 `GlobalHotKeyServicing.unregister()`를 호출해 제어 단축키를 포함한 모든 글로벌 단축키를 해제한다.
- 현재 활성 앱의 bundle identifier를 얻을 수 없으면 앱별 상태와 persistence를 변경하지 않는다.
- 기존 앱별 disabled 목록 키 `disabled_hot_key_applications`와 `ZapAppModel.toggleHotKeysForActiveApplication()`을 그대로 사용한다.
- 새 단축키는 전용 `UserDefaults` 키 `active_application_toggle_shortcut`에 JSON으로 저장한다.
- 손상된 JSON은 미설정 상태로 복구하고 손상된 저장값을 삭제한다.
- 기존 modifier 없는 입력 거부, Escape 취소, key display 변환, planner conflict 문구와 Carbon 오류 수집 방식을 유지한다.
- 새 외부 dependency나 `Package.swift` 변경은 필요하지 않다.
- 이 계획의 commit 단계는 구현 세션에서만 실행한다. 계획 작성 중에는 commit하지 않는다.

---

## Existing Interface Baseline

구현자는 다음 현재 signature를 기준으로 변경해야 한다.

### Current planner

```swift
func plan(
    modifiers: Set<ShortcutModifier>,
    finderShortcutEnabled: Bool,
    manualShortcuts: [ManualShortcut],
    windowShortcuts: [WindowShortcut]
) -> HotKeyRegistrationPlan
```

위치: `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Services/GlobalHotKeyService.swift:53-99`

### Current hotkey service protocol

```swift
protocol GlobalHotKeyServicing: AnyObject {
    func register(
        modifiers: Set<ShortcutModifier>,
        finderShortcutEnabled: Bool,
        manualShortcuts: [ManualShortcut],
        windowShortcuts: [WindowShortcut]
    ) -> String?

    func unregister()
}
```

위치: `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Services/GlobalHotKeyService.swift:34-43`

### Existing shared state mutation

```swift
func toggleHotKeysForActiveApplication()
```

위치: `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/ViewModels/ZapAppModel.swift:247-256`

메뉴바와 새 Carbon callback 모두 이 메서드를 호출해야 한다. 별도의 toggle 구현을 만들지 않는다.

### Existing recorder initializers

```swift
init(
    appName: String,
    onRecord: @escaping (RecordedShortcut) -> Void,
    onCancel: @escaping () -> Void
)

init(
    windowActionName: String,
    onRecord: @escaping (RecordedShortcut) -> Void,
    onCancel: @escaping () -> Void
)
```

위치: `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Views/ShortcutRecorderView.swift:18-32`

### Confirmed test and build commands

- `/Users/woosublee/Documents/dev/zap/Makefile:285-286`의 `make test`는 `swift test`를 실행한다.
- `/Users/woosublee/Documents/dev/zap/.github/workflows/release.yml:75`도 `swift test`를 사용한다.
- 집중 테스트는 저장소 기존 계획과 동일하게 `swift test --filter <TestClass[/testMethod]>` 형식을 사용한다.
- 최종 개발 앱 빌드는 설계 문서대로 `make dev-build CODESIGN_IDENTITY=-`를 사용한다.

---

## File Responsibility Map

### Create

- `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Models/ActiveApplicationToggleShortcut.swift`
  - 제어 단축키의 Codable 값, unset 기본값, 등록 가능 여부, keycap 표시 문자열만 담당한다.
- `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/ActiveApplicationToggleShortcutTests.swift`
  - 모델 기본값, 표시, Codable round trip을 검증한다.
- `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/SettingsShortcutControlsUITests.swift`
  - General 카드 위치와 recorder/Clear 연결을 기존 source-structure 테스트 관례로 검증한다.

### Modify

- `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Services/GlobalHotKeyService.swift`
  - `.activeApplicationToggle` owner, ID `3000`, 최고 우선순위 계획, control-only scope, Carbon 등록 오류, dispatch callback을 담당한다.
- `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/ViewModels/ZapAppModel.swift`
  - 상태/persistence, set/Clear API, callback 연결, Pause/app-disabled별 scope 선택을 담당한다.
- `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Views/ShortcutRecorderView.swift`
  - 제어 단축키용 recorder copy/context initializer를 추가한다.
- `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Views/SettingsView.swift`
  - General의 `Shortcut Controls` 카드와 recorder presentation을 담당한다.
- `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/GlobalHotKeyRegistrationPlanTests.swift`
  - owner 우선순위, 충돌, unset, control-only scope를 검증한다.
- `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/GlobalHotKeyDispatchMappingTests.swift`
  - ID `3000` dispatch와 Carbon 실패 오류 문구를 검증한다.
- `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/ZapAppModelHotKeyIntegrationTests.swift`
  - persistence, callback, runtime scope 전환, Pause, 앱 전환을 검증한다.
- `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/ShortcutRecorderViewTests.swift`
  - 제어 단축키 recorder context가 추가되었는지 검증한다.

---

### Task 1: Add the Codable active-application toggle shortcut model

**Files:**
- Create: `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Models/ActiveApplicationToggleShortcut.swift`
- Create: `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/ActiveApplicationToggleShortcutTests.swift`

**Interfaces:**
- Consumes: `ShortcutModifier`, `ShortcutKeyDisplay.displayName(forKeyCode:fallback:)`
- Produces:
  - `ActiveApplicationToggleShortcut.unset`
  - `var canRegister: Bool`
  - `var shortcutTitle: String?`

- [ ] **Step 1: Write the failing model tests**

Create `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/ActiveApplicationToggleShortcutTests.swift`:

```swift
import XCTest
@testable import ZapApp
@testable import ZapCore

final class ActiveApplicationToggleShortcutTests: XCTestCase {
    func testUnsetShortcutHasNoRegistrationOrDisplayValue() {
        let shortcut = ActiveApplicationToggleShortcut.unset

        XCTAssertNil(shortcut.keyCode)
        XCTAssertNil(shortcut.keyDisplayName)
        XCTAssertEqual(shortcut.modifiers, [])
        XCTAssertFalse(shortcut.canRegister)
        XCTAssertNil(shortcut.shortcutTitle)
    }

    func testConfiguredShortcutCanRegisterAndBuildsKeycapTitle() {
        let shortcut = ActiveApplicationToggleShortcut(
            keyCode: 123,
            keyDisplayName: "←",
            modifiers: [.control, .option]
        )

        XCTAssertTrue(shortcut.canRegister)
        XCTAssertEqual(shortcut.shortcutTitle, "⌃⌥←")
    }

    func testShortcutCodableRoundTripPreservesAllFields() throws {
        let shortcut = ActiveApplicationToggleShortcut(
            keyCode: 17,
            keyDisplayName: "T",
            modifiers: [.command, .shift]
        )

        let data = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(
            ActiveApplicationToggleShortcut.self,
            from: data
        )

        XCTAssertEqual(decoded, shortcut)
    }

    func testKeyWithoutModifiersIsNotRegisterable() {
        let shortcut = ActiveApplicationToggleShortcut(
            keyCode: 17,
            keyDisplayName: "T",
            modifiers: []
        )

        XCTAssertFalse(shortcut.canRegister)
        XCTAssertNil(shortcut.shortcutTitle)
    }
}
```

- [ ] **Step 2: Run the focused test and verify red**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test --filter ActiveApplicationToggleShortcutTests
```

Expected: FAIL to compile with `cannot find 'ActiveApplicationToggleShortcut' in scope`.

- [ ] **Step 3: Add the minimal model implementation**

Create `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Models/ActiveApplicationToggleShortcut.swift`:

```swift
import Foundation
import ZapCore

struct ActiveApplicationToggleShortcut: Codable, Equatable {
    var keyCode: UInt32?
    var keyDisplayName: String?
    var modifiers: Set<ShortcutModifier>

    static let unset = ActiveApplicationToggleShortcut(
        keyCode: nil,
        keyDisplayName: nil,
        modifiers: []
    )

    var canRegister: Bool {
        keyCode != nil && !modifiers.isEmpty
    }

    var shortcutTitle: String? {
        guard let keyCode, !modifiers.isEmpty else { return nil }

        let modifierSymbols = ShortcutModifier.allCases
            .filter(modifiers.contains)
            .map(\.symbol)
            .joined()

        let key = ShortcutKeyDisplay.displayName(
            forKeyCode: keyCode,
            fallback: keyDisplayName
        )
        return modifierSymbols + key
    }
}
```

Do not add `isEnabled`; unset versus configured is the only enable state.

- [ ] **Step 4: Run the focused test and verify green**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test --filter ActiveApplicationToggleShortcutTests
```

Expected: PASS for all four tests.

- [ ] **Step 5: Commit the model slice**

```bash
git -C /Users/woosublee/Documents/dev/zap add -- \
  Sources/ZapApp/Models/ActiveApplicationToggleShortcut.swift \
  Tests/ZapAppTests/ActiveApplicationToggleShortcutTests.swift

git -C /Users/woosublee/Documents/dev/zap commit \
  -m "feat: add active app toggle shortcut model" \
  -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: Give the control owner highest planner priority and add a control-only scope

**Files:**
- Modify: `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Services/GlobalHotKeyService.swift:5-218`
- Modify: `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/GlobalHotKeyRegistrationPlanTests.swift:6-266`

**Interfaces:**
- Consumes: `ActiveApplicationToggleShortcut`
- Produces:
  - `PlannedHotKeyOwner.activeApplicationToggle`
  - `GlobalHotKeyRegistrationScope.all`
  - `GlobalHotKeyRegistrationScope.activeApplicationToggleOnly`
  - `GlobalHotKeyRegistrationPlanner.activeApplicationToggleHotKeyID == 3000`
  - extended `plan(...activeApplicationToggleShortcut:scope:)`

- [ ] **Step 1: Write failing planner tests**

Add these tests to `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/GlobalHotKeyRegistrationPlanTests.swift`:

```swift
func testActiveApplicationTogglePlansFirstWithReservedID() {
    let shortcut = ActiveApplicationToggleShortcut(
        keyCode: 17,
        keyDisplayName: "T",
        modifiers: [.control, .option]
    )

    let plan = planner.plan(
        modifiers: [.option],
        finderShortcutEnabled: true,
        manualShortcuts: [],
        windowShortcuts: [],
        activeApplicationToggleShortcut: shortcut
    )

    XCTAssertEqual(
        plan.hotKeys.first,
        PlannedHotKey(
            id: 3000,
            keyCode: 17,
            modifiers: UInt32(controlKey | optionKey),
            owner: .activeApplicationToggle
        )
    )
}

func testActiveApplicationToggleWinsFinderConflict() {
    let keyCode = UInt32(kVK_ANSI_Grave)
    let combo = HotKeyCombo(
        keyCode: keyCode,
        modifiers: UInt32(optionKey)
    )

    let plan = planner.plan(
        modifiers: [.option],
        finderShortcutEnabled: true,
        manualShortcuts: [],
        windowShortcuts: [],
        activeApplicationToggleShortcut: ActiveApplicationToggleShortcut(
            keyCode: keyCode,
            keyDisplayName: "`",
            modifiers: [.option]
        )
    )

    XCTAssertEqual(
        plan.hotKeys.filter { $0.combo == combo }.map(\.owner),
        [.activeApplicationToggle]
    )
}

func testActiveApplicationToggleWinsDockManualAndWindowConflict() {
    let keyCode = NumberKey.one.carbonKeyCode
    let controlShortcut = ActiveApplicationToggleShortcut(
        keyCode: keyCode,
        keyDisplayName: "1",
        modifiers: [.option]
    )

    let plan = planner.plan(
        modifiers: [.option],
        finderShortcutEnabled: false,
        manualShortcuts: [
            manualShortcut(
                name: "Terminal",
                keyCode: keyCode,
                modifiers: [.option]
            )
        ],
        windowShortcuts: [
            windowShortcut(
                .fullscreen,
                keyCode: keyCode,
                modifiers: [.option]
            )
        ],
        activeApplicationToggleShortcut: controlShortcut
    )

    let combo = HotKeyCombo(
        keyCode: keyCode,
        modifiers: UInt32(optionKey)
    )
    XCTAssertEqual(
        plan.hotKeys.filter { $0.combo == combo }.map(\.owner),
        [.activeApplicationToggle]
    )
    XCTAssertTrue(plan.errors.contains(
        "Some Dock shortcuts could not be registered: 1 (conflict)"
    ))
    XCTAssertTrue(plan.errors.contains(
        "Some manual shortcuts could not be registered: Terminal (conflict)"
    ))
    XCTAssertTrue(plan.errors.contains(
        "Some window shortcuts could not be registered: Fullscreen (conflict)"
    ))
}

func testUnsetActiveApplicationToggleIsNotPlanned() {
    let plan = planner.plan(
        modifiers: [.option],
        finderShortcutEnabled: false,
        manualShortcuts: [],
        windowShortcuts: [],
        activeApplicationToggleShortcut: .unset
    )

    XCTAssertFalse(plan.hotKeys.contains { $0.owner == .activeApplicationToggle })
}

func testActiveApplicationToggleOnlyScopeOmitsAllRegularOwners() {
    let plan = planner.plan(
        modifiers: [.option],
        finderShortcutEnabled: true,
        manualShortcuts: [
            manualShortcut(
                name: "Terminal",
                keyCode: 17,
                modifiers: [.control]
            )
        ],
        windowShortcuts: [
            windowShortcut(
                .center,
                keyCode: 8,
                modifiers: [.command]
            )
        ],
        activeApplicationToggleShortcut: ActiveApplicationToggleShortcut(
            keyCode: 45,
            keyDisplayName: "N",
            modifiers: [.control, .option]
        ),
        scope: .activeApplicationToggleOnly
    )

    XCTAssertEqual(plan.hotKeys.map(\.owner), [.activeApplicationToggle])
    XCTAssertEqual(plan.errors, [])
}
```

Keep the existing `PlannedHotKey.combo` test extension. Do not introduce Carbon registration into planner tests.

- [ ] **Step 2: Run planner tests and verify red**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test --filter GlobalHotKeyRegistrationPlanTests
```

Expected: FAIL with compile errors for missing `.activeApplicationToggle`, missing `GlobalHotKeyRegistrationScope`, and extra planner arguments.

- [ ] **Step 3: Extend the pure planner with the new owner, ID, and scope**

In `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Services/GlobalHotKeyService.swift`, extend the owner and add the scope:

```swift
enum PlannedHotKeyOwner: Equatable {
    case activeApplicationToggle
    case finder
    case dock(NumberKey)
    case manual(UUID, name: String)
    case window(WindowAction, title: String)
}

enum GlobalHotKeyRegistrationScope: Equatable {
    case all
    case activeApplicationToggleOnly
}
```

Change the planner signature while retaining defaults so existing production callers still compile during this task:

```swift
struct GlobalHotKeyRegistrationPlanner {
    static let activeApplicationToggleHotKeyID: UInt32 = 3000

    func plan(
        modifiers: Set<ShortcutModifier>,
        finderShortcutEnabled: Bool,
        manualShortcuts: [ManualShortcut],
        windowShortcuts: [WindowShortcut],
        activeApplicationToggleShortcut: ActiveApplicationToggleShortcut = .unset,
        scope: GlobalHotKeyRegistrationScope = .all
    ) -> HotKeyRegistrationPlan {
        var plannedHotKeys: [PlannedHotKey] = []
        var errors: [String] = []
        var registeredCombos = Set<HotKeyCombo>()

        planActiveApplicationToggle(
            activeApplicationToggleShortcut,
            into: &plannedHotKeys,
            registeredCombos: &registeredCombos
        )

        guard scope == .all else {
            return HotKeyRegistrationPlan(
                hotKeys: plannedHotKeys,
                errors: errors
            )
        }

        if finderShortcutEnabled {
            planFinderHotKeys(
                into: &plannedHotKeys,
                registeredCombos: &registeredCombos
            )
        }

        if modifiers.isEmpty {
            errors.append("Select at least one modifier key.")
        } else {
            let dockFailures = planDockHotKeys(
                modifiers: modifiers,
                into: &plannedHotKeys,
                registeredCombos: &registeredCombos
            )
            if !dockFailures.isEmpty {
                errors.append(
                    "Some Dock shortcuts could not be registered: "
                    + dockFailures.joined(separator: ", ")
                )
            }
        }

        let manualFailures = planManualHotKeys(
            manualShortcuts,
            into: &plannedHotKeys,
            registeredCombos: &registeredCombos
        )
        if !manualFailures.isEmpty {
            errors.append(
                "Some manual shortcuts could not be registered: "
                + manualFailures.joined(separator: ", ")
            )
        }

        let windowFailures = planWindowHotKeys(
            windowShortcuts,
            into: &plannedHotKeys,
            registeredCombos: &registeredCombos
        )
        if !windowFailures.isEmpty {
            errors.append(
                "Some window shortcuts could not be registered: "
                + windowFailures.joined(separator: ", ")
            )
        }

        return HotKeyRegistrationPlan(
            hotKeys: plannedHotKeys,
            errors: errors
        )
    }

    private func planActiveApplicationToggle(
        _ shortcut: ActiveApplicationToggleShortcut,
        into plannedHotKeys: inout [PlannedHotKey],
        registeredCombos: inout Set<HotKeyCombo>
    ) {
        guard shortcut.canRegister,
              let keyCode = shortcut.keyCode else {
            return
        }

        let modifiers = Self.carbonModifiers(for: shortcut.modifiers)
        let combo = HotKeyCombo(
            keyCode: keyCode,
            modifiers: modifiers
        )

        plannedHotKeys.append(PlannedHotKey(
            id: Self.activeApplicationToggleHotKeyID,
            keyCode: keyCode,
            modifiers: modifiers,
            owner: .activeApplicationToggle
        ))
        registeredCombos.insert(combo)
    }
}
```

The call to `planActiveApplicationToggle` must remain before `planFinderHotKeys`.

- [ ] **Step 4: Make existing service switches exhaustive without adding dispatch yet**

The new owner makes the existing service switches non-exhaustive. Add the minimal cases:

```swift
switch hotKey.owner {
case .activeApplicationToggle:
    break
case .finder:
    finderFailures.append("\(hotKey.keyCode) (\(result.status))")
case let .dock(key):
    dockFailures.append("\(key.displayName) (\(result.status))")
case let .manual(_, name):
    manualFailures.append("\(name) (\(result.status))")
case let .window(_, title):
    windowFailures.append("\(title) (\(result.status))")
}
```

And:

```swift
private func registerSuccessfulOwner(for hotKey: PlannedHotKey) {
    switch hotKey.owner {
    case .activeApplicationToggle, .finder, .dock:
        break
    case let .manual(id, _):
        manualHotKeyIDs[hotKey.id] = id
    case let .window(action, _):
        windowHotKeyIDs[hotKey.id] = action
    }
}
```

Task 3 will replace the temporary registration-failure `break` with proper error collection.

- [ ] **Step 5: Run planner tests and verify green**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test --filter GlobalHotKeyRegistrationPlanTests
```

Expected: PASS, including the pre-existing Finder, Dock, Manual, Window tests.

- [ ] **Step 6: Commit the planner slice**

```bash
git -C /Users/woosublee/Documents/dev/zap add -- \
  Sources/ZapApp/Services/GlobalHotKeyService.swift \
  Tests/ZapAppTests/GlobalHotKeyRegistrationPlanTests.swift

git -C /Users/woosublee/Documents/dev/zap commit \
  -m "feat: prioritize active app toggle hotkey planning" \
  -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Register and dispatch the control hotkey through GlobalHotKeyService

**Files:**
- Modify: `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Services/GlobalHotKeyService.swift:29-427`
- Modify: `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/ViewModels/ZapAppModel.swift:103-167,350-362`
- Modify: `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/GlobalHotKeyDispatchMappingTests.swift:6-177`
- Modify: `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/ZapAppModelHotKeyIntegrationTests.swift:39-141,344-492`

**Interfaces:**
- Consumes: planner owner, ID, and scope from Task 2
- Produces:
  - extended `GlobalHotKeyServicing.register(...activeApplicationToggleShortcut:scope:)`
  - `GlobalHotKeyService.init(...onActiveApplicationToggleHotKey:)`
  - Carbon ID `3000` dispatch to the existing app toggle method

- [ ] **Step 1: Write failing service dispatch and error tests**

Add to `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/GlobalHotKeyDispatchMappingTests.swift`:

```swift
func testDispatchActiveApplicationToggleIDInvokesOnlyToggleCallback() {
    let expectation = expectation(
        description: "Active application toggle callback"
    )
    var toggleCallCount = 0

    let service = makeRegisteredService(
        activeApplicationToggleShortcut: ActiveApplicationToggleShortcut(
            keyCode: 17,
            keyDisplayName: "T",
            modifiers: [.control, .option]
        ),
        onDockHotKey: { _ in
            XCTFail("Control ID must not invoke Dock callback.")
        },
        onFinderHotKey: {
            XCTFail("Control ID must not invoke Finder callback.")
        },
        onManualHotKey: { _ in
            XCTFail("Control ID must not invoke manual callback.")
        },
        onWindowHotKey: { _ in
            XCTFail("Control ID must not invoke window callback.")
        },
        onActiveApplicationToggleHotKey: {
            toggleCallCount += 1
            expectation.fulfill()
        }
    )

    XCTAssertTrue(service.dispatchHotKey(id: 3000))

    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(toggleCallCount, 1)
}

func testActiveApplicationToggleCarbonFailureUsesRegistrationError() {
    let service = GlobalHotKeyService(
        onDockHotKey: { _ in },
        onFinderHotKey: {},
        onManualHotKey: { _ in },
        onWindowHotKey: { _ in },
        onActiveApplicationToggleHotKey: {},
        registerHotKey: { hotKey in
            if hotKey.owner == .activeApplicationToggle {
                return HotKeyRegistrationResult(
                    status: OSStatus(-9876),
                    ref: nil
                )
            }
            return HotKeyRegistrationResult(status: noErr, ref: nil)
        }
    )

    let error = service.register(
        modifiers: [.option],
        finderShortcutEnabled: false,
        manualShortcuts: [],
        windowShortcuts: [],
        activeApplicationToggleShortcut: ActiveApplicationToggleShortcut(
            keyCode: 17,
            keyDisplayName: "T",
            modifiers: [.control]
        ),
        scope: .all
    )

    XCTAssertEqual(
        error,
        "Toggle Zap for Current App shortcut could not be registered: -9876"
    )
}
```

Extend the test helper signature:

```swift
private func makeRegisteredService(
    finderShortcutEnabled: Bool = false,
    manualShortcuts: [ManualShortcut] = [],
    windowShortcuts: [WindowShortcut] = [],
    activeApplicationToggleShortcut: ActiveApplicationToggleShortcut = .unset,
    scope: GlobalHotKeyRegistrationScope = .all,
    onDockHotKey: @escaping (NumberKey) -> Void = { _ in },
    onFinderHotKey: @escaping () -> Void = {},
    onManualHotKey: @escaping (UUID) -> Void = { _ in },
    onWindowHotKey: @escaping (WindowAction) -> Void = { _ in },
    onActiveApplicationToggleHotKey: @escaping () -> Void = {}
) -> GlobalHotKeyService
```

The helper must pass the callback to the initializer and the shortcut/scope to `register`.

- [ ] **Step 2: Write a failing model callback integration test**

Add to `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/ZapAppModelHotKeyIntegrationTests.swift`:

```swift
func testActiveApplicationToggleCallbackUsesExistingToggleMethod() async {
    let suiteName = "ActiveApplicationToggleCallback.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let hotKeyService = CapturingHotKeyService()
    let model = makeModel(
        windowManagementModel: WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
        ),
        hotKeyService: hotKeyService,
        userDefaults: defaults,
        activeApplicationProvider: {
            ActiveApplication(
                name: "Safari",
                bundleIdentifier: "com.apple.Safari"
            )
        }
    )

    hotKeyService.onActiveApplicationToggleHotKey?()
    await Task.yield()

    XCTAssertTrue(model.isActiveApplicationDisabled)
    XCTAssertEqual(
        defaults.dictionary(forKey: "disabled_hot_key_applications")
            as? [String: String],
        ["com.apple.Safari": "Safari"]
    )
}
```

- [ ] **Step 3: Run dispatch and integration tests and verify red**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test --filter GlobalHotKeyDispatchMappingTests
swift test --filter ZapAppModelHotKeyIntegrationTests/testActiveApplicationToggleCallbackUsesExistingToggleMethod
```

Expected:

- dispatch tests fail to compile because `GlobalHotKeyService` lacks the callback and extended `register` signature;
- integration test fails because `CapturingHotKeyService` and `ZapAppModel.hotKeyServiceFactory` expose only four callbacks.

- [ ] **Step 4: Extend the service protocol and concrete service**

Replace the protocol requirement in `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Services/GlobalHotKeyService.swift`:

```swift
protocol GlobalHotKeyServicing: AnyObject {
    func register(
        modifiers: Set<ShortcutModifier>,
        finderShortcutEnabled: Bool,
        manualShortcuts: [ManualShortcut],
        windowShortcuts: [WindowShortcut],
        activeApplicationToggleShortcut: ActiveApplicationToggleShortcut,
        scope: GlobalHotKeyRegistrationScope
    ) -> String?

    func unregister()
}
```

Add the callback property and initializer argument:

```swift
private let onActiveApplicationToggleHotKey: () -> Void

init(
    onDockHotKey: @escaping (NumberKey) -> Void,
    onFinderHotKey: @escaping () -> Void,
    onManualHotKey: @escaping (UUID) -> Void,
    onWindowHotKey: @escaping (WindowAction) -> Void,
    onActiveApplicationToggleHotKey: @escaping () -> Void,
    planner: GlobalHotKeyRegistrationPlanner = GlobalHotKeyRegistrationPlanner(),
    registerHotKey: @escaping (PlannedHotKey) -> HotKeyRegistrationResult =
        GlobalHotKeyService.registerCarbonHotKey
) {
    self.onDockHotKey = onDockHotKey
    self.onFinderHotKey = onFinderHotKey
    self.onManualHotKey = onManualHotKey
    self.onWindowHotKey = onWindowHotKey
    self.onActiveApplicationToggleHotKey =
        onActiveApplicationToggleHotKey
    self.planner = planner
    self.registerHotKey = registerHotKey
    installHandler()
}
```

Extend the concrete `register` method:

```swift
func register(
    modifiers: Set<ShortcutModifier>,
    finderShortcutEnabled: Bool,
    manualShortcuts: [ManualShortcut],
    windowShortcuts: [WindowShortcut] = [],
    activeApplicationToggleShortcut: ActiveApplicationToggleShortcut,
    scope: GlobalHotKeyRegistrationScope
) -> String? {
    unregister()

    let plan = planner.plan(
        modifiers: modifiers,
        finderShortcutEnabled: finderShortcutEnabled,
        manualShortcuts: manualShortcuts,
        windowShortcuts: windowShortcuts,
        activeApplicationToggleShortcut:
            activeApplicationToggleShortcut,
        scope: scope
    )

    var errors = plan.errors
    var activeApplicationToggleFailures: [String] = []
    var finderFailures: [String] = []
    var dockFailures: [String] = []
    var manualFailures: [String] = []
    var windowFailures: [String] = []

    for hotKey in plan.hotKeys {
        let result = registerHotKey(hotKey)
        if result.status == noErr {
            if let ref = result.ref {
                hotKeyRefs.append(ref)
            }
            registerSuccessfulOwner(for: hotKey)
        } else {
            switch hotKey.owner {
            case .activeApplicationToggle:
                activeApplicationToggleFailures.append(
                    "\(result.status)"
                )
            case .finder:
                finderFailures.append(
                    "\(hotKey.keyCode) (\(result.status))"
                )
            case let .dock(key):
                dockFailures.append(
                    "\(key.displayName) (\(result.status))"
                )
            case let .manual(_, name):
                manualFailures.append(
                    "\(name) (\(result.status))"
                )
            case let .window(_, title):
                windowFailures.append(
                    "\(title) (\(result.status))"
                )
            }
        }
    }

    if !activeApplicationToggleFailures.isEmpty {
        errors.append(
            "Toggle Zap for Current App shortcut could not be registered: "
            + activeApplicationToggleFailures.joined(separator: ", ")
        )
    }

    // Preserve the existing Finder, Dock, Manual, and Window
    // error aggregation immediately after this block.

    return errors.isEmpty ? nil : errors.joined(separator: " ")
}
```

Add the fixed-ID dispatch before Finder dispatch:

```swift
@discardableResult
func dispatchHotKey(id: UInt32) -> Bool {
    if id == GlobalHotKeyRegistrationPlanner
        .activeApplicationToggleHotKeyID {
        DispatchQueue.main.async {
            [onActiveApplicationToggleHotKey] in
            onActiveApplicationToggleHotKey()
        }
        return true
    }

    if Self.finderHotKeyIDs.contains(id) {
        DispatchQueue.main.async { [onFinderHotKey] in
            onFinderHotKey()
        }
        return true
    }

    // Keep existing manual, window, and Dock routing unchanged.
}
```

- [ ] **Step 5: Add the fifth callback to ZapAppModel’s factory**

In `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/ViewModels/ZapAppModel.swift`, append the callback to the factory signature:

```swift
private let hotKeyServiceFactory: (
    @escaping (NumberKey) -> Void,
    @escaping () -> Void,
    @escaping (UUID) -> Void,
    @escaping (WindowAction) -> Void,
    @escaping () -> Void
) -> any GlobalHotKeyServicing
```

Append the callback to `hotKeyServiceFactory(...)`:

```swift
private lazy var hotKeyService: any GlobalHotKeyServicing =
    hotKeyServiceFactory(
        { [weak self] key in
            Task { @MainActor [weak self] in
                self?.activateDockItem(for: key)
            }
        },
        { [weak self] in
            Task { @MainActor [weak self] in
                self?.activateFinder()
            }
        },
        { [weak self] id in
            Task { @MainActor [weak self] in
                self?.activateManualShortcut(id: id)
            }
        },
        { [weak self] action in
            Task { @MainActor [weak self] in
                _ = self?.windowManagementModel.perform(
                    action: action
                )
            }
        },
        { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggleHotKeysForActiveApplication()
            }
        }
    )
```

Change the initializer factory parameter and default factory:

```swift
hotKeyServiceFactory: @escaping (
    @escaping (NumberKey) -> Void,
    @escaping () -> Void,
    @escaping (UUID) -> Void,
    @escaping (WindowAction) -> Void,
    @escaping () -> Void
) -> any GlobalHotKeyServicing = {
    onDockHotKey,
    onFinderHotKey,
    onManualHotKey,
    onWindowHotKey,
    onActiveApplicationToggleHotKey in

    GlobalHotKeyService(
        onDockHotKey: onDockHotKey,
        onFinderHotKey: onFinderHotKey,
        onManualHotKey: onManualHotKey,
        onWindowHotKey: onWindowHotKey,
        onActiveApplicationToggleHotKey:
            onActiveApplicationToggleHotKey
    )
}
```

Until Task 4 introduces model state, pass the unset value and full scope:

```swift
registrationError = hotKeyService.register(
    modifiers: selectedModifiers,
    finderShortcutEnabled: isFinderShortcutEnabled,
    manualShortcuts: manualShortcuts,
    windowShortcuts:
        windowManagementModel.windowShortcutsForRegistration,
    activeApplicationToggleShortcut: .unset,
    scope: .all
)
```

Update `CapturingHotKeyService` to conform to the new signature and expose:

```swift
var onActiveApplicationToggleHotKey: (() -> Void)?
```

Update `makeModel`’s factory closure:

```swift
hotKeyServiceFactory: {
    onDockHotKey,
    onFinderHotKey,
    onManualHotKey,
    onWindowHotKey,
    onActiveApplicationToggleHotKey in

    hotKeyService.onDockHotKey = onDockHotKey
    hotKeyService.onFinderHotKey = onFinderHotKey
    hotKeyService.onManualHotKey = onManualHotKey
    hotKeyService.onWindowHotKey = onWindowHotKey
    hotKeyService.onActiveApplicationToggleHotKey =
        onActiveApplicationToggleHotKey
    return hotKeyService
}
```

- [ ] **Step 6: Run the focused tests and verify green**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test --filter GlobalHotKeyDispatchMappingTests
swift test --filter ZapAppModelHotKeyIntegrationTests/testActiveApplicationToggleCallbackUsesExistingToggleMethod
```

Expected: PASS. ID `3000` routes only to the control callback, registration failure reaches the expected error text, and the callback changes the same disabled-app dictionary as the menu action.

- [ ] **Step 7: Commit the service dispatch slice**

```bash
git -C /Users/woosublee/Documents/dev/zap add -- \
  Sources/ZapApp/Services/GlobalHotKeyService.swift \
  Sources/ZapApp/ViewModels/ZapAppModel.swift \
  Tests/ZapAppTests/GlobalHotKeyDispatchMappingTests.swift \
  Tests/ZapAppTests/ZapAppModelHotKeyIntegrationTests.swift

git -C /Users/woosublee/Documents/dev/zap commit \
  -m "feat: dispatch active app toggle hotkey" \
  -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Persist the control shortcut and select registration scope from runtime state

**Files:**
- Modify: `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/ViewModels/ZapAppModel.swift:51-197,212-256,350-362,458-492`
- Modify: `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/ZapAppModelHotKeyIntegrationTests.swift:17-558`

**Interfaces:**
- Consumes: extended service API from Task 3
- Produces:
  - `@Published private(set) var activeApplicationToggleShortcut`
  - `setActiveApplicationToggleShortcut(keyCode:keyDisplayName:modifiers:)`
  - `clearActiveApplicationToggleShortcut()`
  - runtime selection of `.all` versus `.activeApplicationToggleOnly`

- [ ] **Step 1: Extend the capturing service record before writing behavior tests**

Change the test double’s `Registration`:

```swift
struct Registration: Equatable {
    let modifiers: Set<ShortcutModifier>
    let finderShortcutEnabled: Bool
    let manualShortcuts: [ManualShortcut]
    let windowShortcuts: [WindowShortcut]
    let activeApplicationToggleShortcut:
        ActiveApplicationToggleShortcut
    let scope: GlobalHotKeyRegistrationScope
}
```

Update its `register` implementation:

```swift
func register(
    modifiers: Set<ShortcutModifier>,
    finderShortcutEnabled: Bool,
    manualShortcuts: [ManualShortcut],
    windowShortcuts: [WindowShortcut],
    activeApplicationToggleShortcut:
        ActiveApplicationToggleShortcut,
    scope: GlobalHotKeyRegistrationScope
) -> String? {
    registrations.append(Registration(
        modifiers: modifiers,
        finderShortcutEnabled: finderShortcutEnabled,
        manualShortcuts: manualShortcuts,
        windowShortcuts: windowShortcuts,
        activeApplicationToggleShortcut:
            activeApplicationToggleShortcut,
        scope: scope
    ))
    return nextRegistrationError
}
```

- [ ] **Step 2: Write failing initial-state, persistence, Clear, and recovery tests**

Add to `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/ZapAppModelHotKeyIntegrationTests.swift`:

```swift
func testActiveApplicationToggleShortcutStartsUnset() {
    let hotKeyService = CapturingHotKeyService()
    let model = makeModel(
        windowManagementModel: WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
        ),
        hotKeyService: hotKeyService
    )

    XCTAssertEqual(model.activeApplicationToggleShortcut, .unset)
    XCTAssertEqual(
        hotKeyService.registrations.last?
            .activeApplicationToggleShortcut,
        .unset
    )
    XCTAssertEqual(hotKeyService.registrations.last?.scope, .all)
}

func testSettingActiveApplicationToggleShortcutPersistsAndReregisters() throws {
    let suiteName = "ActiveApplicationTogglePersistence.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let hotKeyService = CapturingHotKeyService()
    let model = makeModel(
        windowManagementModel: WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
        ),
        hotKeyService: hotKeyService,
        userDefaults: defaults
    )
    hotKeyService.registrations.removeAll()

    model.setActiveApplicationToggleShortcut(
        keyCode: 17,
        keyDisplayName: "T",
        modifiers: [.control, .option]
    )

    let data = try XCTUnwrap(defaults.data(
        forKey: "active_application_toggle_shortcut"
    ))
    let stored = try JSONDecoder().decode(
        ActiveApplicationToggleShortcut.self,
        from: data
    )

    XCTAssertEqual(stored, model.activeApplicationToggleShortcut)
    XCTAssertEqual(hotKeyService.registrations.count, 1)
    XCTAssertEqual(
        hotKeyService.registrations[0]
            .activeApplicationToggleShortcut,
        stored
    )

    let restoredService = CapturingHotKeyService()
    let restoredModel = makeModel(
        windowManagementModel: WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
        ),
        hotKeyService: restoredService,
        userDefaults: defaults
    )

    XCTAssertEqual(
        restoredModel.activeApplicationToggleShortcut,
        stored
    )
}

func testClearingActiveApplicationToggleShortcutRemovesStoredValue() {
    let suiteName = "ActiveApplicationToggleClear.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let hotKeyService = CapturingHotKeyService()
    let model = makeModel(
        windowManagementModel: WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
        ),
        hotKeyService: hotKeyService,
        userDefaults: defaults
    )

    model.setActiveApplicationToggleShortcut(
        keyCode: 17,
        keyDisplayName: "T",
        modifiers: [.control]
    )
    hotKeyService.registrations.removeAll()

    model.clearActiveApplicationToggleShortcut()

    XCTAssertEqual(model.activeApplicationToggleShortcut, .unset)
    XCTAssertNil(defaults.data(
        forKey: "active_application_toggle_shortcut"
    ))
    XCTAssertEqual(
        hotKeyService.registrations.last?
            .activeApplicationToggleShortcut,
        .unset
    )
}

func testCorruptActiveApplicationToggleShortcutRestoresUnsetState() {
    let suiteName = "ActiveApplicationToggleCorrupt.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(
        Data([0xFF, 0x00]),
        forKey: "active_application_toggle_shortcut"
    )

    let model = makeModel(
        windowManagementModel: WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
        ),
        hotKeyService: CapturingHotKeyService(),
        userDefaults: defaults
    )

    XCTAssertEqual(model.activeApplicationToggleShortcut, .unset)
    XCTAssertNil(defaults.data(
        forKey: "active_application_toggle_shortcut"
    ))
}
```

- [ ] **Step 3: Write failing runtime registration-state tests**

Add:

```swift
func testDisabledActiveApplicationKeepsOnlyControlRegistrationAndSecondToggleRestoresAll() {
    let suiteName = "ActiveApplicationToggleScope.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    storeActiveApplicationToggleShortcut(
        ActiveApplicationToggleShortcut(
            keyCode: 17,
            keyDisplayName: "T",
            modifiers: [.control, .option]
        ),
        in: defaults
    )

    let hotKeyService = CapturingHotKeyService()
    let model = makeModel(
        windowManagementModel: WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
        ),
        hotKeyService: hotKeyService,
        userDefaults: defaults,
        activeApplicationProvider: {
            ActiveApplication(
                name: "Safari",
                bundleIdentifier: "com.apple.Safari"
            )
        }
    )
    hotKeyService.registrations.removeAll()
    hotKeyService.unregisterCallCount = 0

    model.toggleHotKeysForActiveApplication()

    XCTAssertTrue(model.isActiveApplicationDisabled)
    XCTAssertEqual(hotKeyService.unregisterCallCount, 0)
    XCTAssertEqual(
        hotKeyService.registrations.last?.scope,
        .activeApplicationToggleOnly
    )

    model.toggleHotKeysForActiveApplication()

    XCTAssertFalse(model.isActiveApplicationDisabled)
    XCTAssertEqual(hotKeyService.registrations.last?.scope, .all)
}

func testGlobalPauseUnregistersControlAndRegularHotKeys() {
    let suiteName = "ActiveApplicationTogglePause.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    storeActiveApplicationToggleShortcut(
        ActiveApplicationToggleShortcut(
            keyCode: 17,
            keyDisplayName: "T",
            modifiers: [.control]
        ),
        in: defaults
    )

    let hotKeyService = CapturingHotKeyService()
    let model = makeModel(
        windowManagementModel: WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
        ),
        hotKeyService: hotKeyService,
        userDefaults: defaults
    )
    hotKeyService.registrations.removeAll()
    hotKeyService.unregisterCallCount = 0

    model.pauseHotKeysIndefinitely()

    XCTAssertEqual(hotKeyService.unregisterCallCount, 1)
    XCTAssertEqual(hotKeyService.registrations, [])
}

func testMissingActiveApplicationDoesNotChangeDisabledStateOrPersistence() async {
    let suiteName = "ActiveApplicationToggleMissingApp.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let hotKeyService = CapturingHotKeyService()
    let model = makeModel(
        windowManagementModel: WindowManagementModel(
            service: CapturingWindowManagementPerformer(),
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: [])
        ),
        hotKeyService: hotKeyService,
        userDefaults: defaults,
        activeApplicationProvider: { nil }
    )
    hotKeyService.registrations.removeAll()

    hotKeyService.onActiveApplicationToggleHotKey?()
    await Task.yield()

    XCTAssertEqual(model.disabledApplications, [:])
    XCTAssertNil(defaults.dictionary(
        forKey: "disabled_hot_key_applications"
    ))
    XCTAssertEqual(hotKeyService.registrations, [])
}
```

Add the helper:

```swift
private func storeActiveApplicationToggleShortcut(
    _ shortcut: ActiveApplicationToggleShortcut,
    in defaults: UserDefaults
) {
    let data = try! JSONEncoder().encode(shortcut)
    defaults.set(
        data,
        forKey: "active_application_toggle_shortcut"
    )
}
```

Update the existing app-switch test so a disabled app expects `.activeApplicationToggleOnly`, another app expects `.all`, and switching back expects `.activeApplicationToggleOnly` instead of direct `unregister()` calls.

- [ ] **Step 4: Run model integration tests and verify red**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test --filter ZapAppModelHotKeyIntegrationTests
```

Expected: FAIL with missing `activeApplicationToggleShortcut`, missing set/Clear methods, and scope assertions receiving `.all` or `unregister()` under the old logic.

- [ ] **Step 5: Add state, persistence, and public mutation methods**

Add the published state to `ZapAppModel`:

```swift
@Published private(set) var activeApplicationToggleShortcut:
    ActiveApplicationToggleShortcut
```

Load it in `init` using the injected `userDefaults`:

```swift
self.activeApplicationToggleShortcut =
    Self.loadActiveApplicationToggleShortcut(
        from: userDefaults
    )
```

Add the mutation methods next to the existing shortcut mutation methods:

```swift
func setActiveApplicationToggleShortcut(
    keyCode: UInt32,
    keyDisplayName: String,
    modifiers: Set<ShortcutModifier>
) {
    guard !modifiers.isEmpty else { return }

    activeApplicationToggleShortcut =
        ActiveApplicationToggleShortcut(
            keyCode: keyCode,
            keyDisplayName: keyDisplayName,
            modifiers: modifiers
        )
    persistActiveApplicationToggleShortcut()
    registerHotKeys()
}

func clearActiveApplicationToggleShortcut() {
    activeApplicationToggleShortcut = .unset
    userDefaults.removeObject(
        forKey: Self.activeApplicationToggleShortcutKey
    )
    registerHotKeys()
}
```

Add persistence helpers:

```swift
private func persistActiveApplicationToggleShortcut() {
    guard let data = try? JSONEncoder().encode(
        activeApplicationToggleShortcut
    ) else {
        return
    }

    userDefaults.set(
        data,
        forKey: Self.activeApplicationToggleShortcutKey
    )
}

private static func loadActiveApplicationToggleShortcut(
    from userDefaults: UserDefaults
) -> ActiveApplicationToggleShortcut {
    guard let data = userDefaults.data(
        forKey: activeApplicationToggleShortcutKey
    ) else {
        return .unset
    }

    guard let shortcut = try? JSONDecoder().decode(
        ActiveApplicationToggleShortcut.self,
        from: data
    ) else {
        userDefaults.removeObject(
            forKey: activeApplicationToggleShortcutKey
        )
        return .unset
    }

    return shortcut
}
```

Add the key:

```swift
private static let activeApplicationToggleShortcutKey =
    "active_application_toggle_shortcut"
```

- [ ] **Step 6: Replace register-or-unregister logic with explicit runtime scopes**

Replace `registerHotKeys()` with:

```swift
private func registerHotKeys() {
    if areHotKeysPaused {
        hotKeyService.unregister()
        return
    }

    let scope: GlobalHotKeyRegistrationScope =
        isActiveApplicationDisabled
            ? .activeApplicationToggleOnly
            : .all

    registrationError = hotKeyService.register(
        modifiers: selectedModifiers,
        finderShortcutEnabled: isFinderShortcutEnabled,
        manualShortcuts: manualShortcuts,
        windowShortcuts:
            windowManagementModel.windowShortcutsForRegistration,
        activeApplicationToggleShortcut:
            activeApplicationToggleShortcut,
        scope: scope
    )
}
```

Do not change the body or signature of:

```swift
func toggleHotKeysForActiveApplication()
```

The existing menu action and Carbon callback must continue to share it.

Add `active_application_toggle_shortcut` to `clearZapAppModelDefaults()` in tests.

- [ ] **Step 7: Run model integration tests and verify green**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test --filter ZapAppModelHotKeyIntegrationTests
```

Expected:

- initial value is unset;
- record persists and restores;
- Clear removes data and registration;
- corrupt data is removed;
- disabled app uses `.activeApplicationToggleOnly`;
- second toggle restores `.all`;
- app activation transitions select the correct scope;
- global Pause calls `unregister()`;
- missing active application leaves state unchanged.

- [ ] **Step 8: Run planner, service, and model regression tests together**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test --filter GlobalHotKeyRegistrationPlanTests
swift test --filter GlobalHotKeyDispatchMappingTests
swift test --filter ZapAppModelHotKeyIntegrationTests
```

Expected: all three test classes PASS.

- [ ] **Step 9: Commit the model runtime slice**

```bash
git -C /Users/woosublee/Documents/dev/zap add -- \
  Sources/ZapApp/ViewModels/ZapAppModel.swift \
  Tests/ZapAppTests/ZapAppModelHotKeyIntegrationTests.swift

git -C /Users/woosublee/Documents/dev/zap commit \
  -m "feat: persist active app toggle shortcut" \
  -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: Add the recorder context and General > Shortcut Controls UI

**Files:**
- Modify: `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Views/ShortcutRecorderView.swift:11-32`
- Modify: `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Views/SettingsView.swift:14-94,160-204,287-312`
- Modify: `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/ShortcutRecorderViewTests.swift:3-77`
- Create: `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/SettingsShortcutControlsUITests.swift`

**Interfaces:**
- Consumes:
  - `ZapAppModel.activeApplicationToggleShortcut`
  - `setActiveApplicationToggleShortcut(...)`
  - `clearActiveApplicationToggleShortcut()`
- Produces:
  - `ShortcutRecorderView.init(activeApplicationToggleOnRecord:onCancel:)`
  - General `Shortcut Controls` card between Permissions and Behavior

- [ ] **Step 1: Write the failing recorder-context test**

Add to `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/ShortcutRecorderViewTests.swift`:

```swift
func testShortcutRecorderSupportsActiveApplicationToggleCopy() throws {
    let source = try String(contentsOf: packageRootURL
        .appendingPathComponent(
            "Sources/ZapApp/Views/ShortcutRecorderView.swift"
        ))

    XCTAssertTrue(source.contains(
        "activeApplicationToggleOnRecord"
    ))
    XCTAssertTrue(source.contains("Record Shortcut Control"))
    XCTAssertTrue(source.contains(
        "Press the global shortcut that disables or re-enables Zap for the currently active app."
    ))
    XCTAssertTrue(source.contains("Press toggle shortcut"))
}
```

- [ ] **Step 2: Write the failing General UI source-structure tests**

Create `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/SettingsShortcutControlsUITests.swift`:

```swift
import XCTest

final class SettingsShortcutControlsUITests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var settingsSource: String {
        get throws {
            try String(contentsOf: packageRootURL
                .appendingPathComponent(
                    "Sources/ZapApp/Views/SettingsView.swift"
                ))
        }
    }

    func testGeneralPlacesShortcutControlsBetweenPermissionsAndBehavior()
        throws {
        let source = try settingsSource

        XCTAssertTrue(source.contains(
            """
            permissionsSection
            shortcutControlsSection
            behaviorSection
            """
        ))
        XCTAssertTrue(source.contains(
            "SettingsCard(title: \"Shortcut Controls\")"
        ))
    }

    func testShortcutControlsRendersRequiredCopyAndKeycap() throws {
        let source = try settingsSource

        XCTAssertTrue(source.contains(
            "Toggle Zap for Current App"
        ))
        XCTAssertTrue(source.contains(
            "Disable or re-enable Zap shortcuts for the currently active app."
        ))
        XCTAssertTrue(source.contains(
            "ShortcutKeycapGroupView(shortcut: model.activeApplicationToggleShortcut.shortcutTitle)"
        ))
    }

    func testShortcutControlsOpensRecorderAndAppliesRecording()
        throws {
        let source = try settingsSource

        XCTAssertTrue(source.contains(
            "isRecordingActiveApplicationToggleShortcut = true"
        ))
        XCTAssertTrue(source.contains(
            "ShortcutRecorderView("
        ))
        XCTAssertTrue(source.contains(
            "activeApplicationToggleOnRecord:"
        ))
        XCTAssertTrue(source.contains(
            "model.setActiveApplicationToggleShortcut("
        ))
    }

    func testConfiguredShortcutExposesClearAction() throws {
        let source = try settingsSource

        XCTAssertTrue(source.contains(
            "model.activeApplicationToggleShortcut.canRegister"
        ))
        XCTAssertTrue(source.contains(
            "Button(\"Clear\", role: .destructive)"
        ))
        XCTAssertTrue(source.contains(
            "model.clearActiveApplicationToggleShortcut()"
        ))
    }

    func testShortcutControlsDisplaysGlobalRegistrationError()
        throws {
        let source = try settingsSource

        XCTAssertTrue(source.contains(
            "if let registrationError = model.registrationError"
        ))
        XCTAssertTrue(source.contains(
            "Label(registrationError, systemImage: \"exclamationmark.triangle.fill\")"
        ))
    }
}
```

- [ ] **Step 3: Run recorder and UI tests and verify red**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test --filter ShortcutRecorderViewTests
swift test --filter SettingsShortcutControlsUITests
```

Expected: existing recorder tests remain green, while the new tests fail because the control initializer, card, keycap, recorder state, and Clear wiring are absent.

- [ ] **Step 4: Add the control-specific recorder initializer**

In `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Views/ShortcutRecorderView.swift`, add:

```swift
init(
    activeApplicationToggleOnRecord onRecord:
        @escaping (RecordedShortcut) -> Void,
    onCancel: @escaping () -> Void
) {
    self.title = "Record Shortcut Control"
    self.instructions =
        "Press the global shortcut that disables or re-enables Zap for the currently active app."
    self.capturePrompt = "Press toggle shortcut"
    self.onRecord = onRecord
    self.onCancel = onCancel
}
```

Do not change:

```swift
guard !modifiers.isEmpty else
```

or the Escape handling at key code `53`.

- [ ] **Step 5: Add recorder state and presentation to SettingsView**

Add state next to `recordingShortcut`:

```swift
@State private var isRecordingActiveApplicationToggleShortcut =
    false
```

Add a second sheet modifier after the existing manual shortcut sheet:

```swift
.sheet(
    isPresented:
        $isRecordingActiveApplicationToggleShortcut
) {
    ShortcutRecorderView(
        activeApplicationToggleOnRecord: {
            recordedShortcut in

            model.setActiveApplicationToggleShortcut(
                keyCode: recordedShortcut.keyCode,
                keyDisplayName:
                    recordedShortcut.keyDisplayName,
                modifiers: recordedShortcut.modifiers
            )
            isRecordingActiveApplicationToggleShortcut = false
        },
        onCancel: {
            isRecordingActiveApplicationToggleShortcut = false
        }
    )
}
```

- [ ] **Step 6: Insert Shortcut Controls between Permissions and Behavior**

Change `generalSection`:

```swift
private var generalSection: some View {
    VStack(
        alignment: .leading,
        spacing: ZapSpacing.large
    ) {
        permissionsSection
        shortcutControlsSection
        behaviorSection
        updatesSection
    }
}
```

Add the section:

```swift
private var shortcutControlsSection: some View {
    SettingsCard(title: "Shortcut Controls") {
        SettingsRow(
            title: "Toggle Zap for Current App",
            subtitle:
                "Disable or re-enable Zap shortcuts for the currently active app.",
            leading: {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(
                        size: 18,
                        weight: .semibold
                    ))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
            },
            trailing: {
                HStack(spacing: ZapSpacing.medium) {
                    Button {
                        isRecordingActiveApplicationToggleShortcut =
                            true
                    } label: {
                        ShortcutKeycapGroupView(shortcut: model.activeApplicationToggleShortcut.shortcutTitle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "Record Toggle Zap for Current App shortcut"
                    )
                    .help("Record shortcut")

                    if model
                        .activeApplicationToggleShortcut
                        .canRegister {
                        Button(
                            "Clear",
                            role: .destructive
                        ) {
                            model.clearActiveApplicationToggleShortcut()
                        }
                        .controlSize(.small)
                    }
                }
            }
        )

        if let registrationError = model.registrationError {
            Label(
                registrationError,
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.orange)
        }
    }
}
```

The keycap button must remain enabled while the shortcut is unset so the initial `Not set` keycap opens the recorder.

- [ ] **Step 7: Run focused UI tests and verify green**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test --filter ShortcutRecorderViewTests
swift test --filter SettingsShortcutControlsUITests
swift test --filter SettingsWindowManagementUITests
swift test --filter ZapDesignSystemTests
```

Expected:

- the new control recorder copy is present;
- the card appears between Permissions and Behavior;
- unset keycap recording and configured Clear wiring are present;
- existing General, sidebar, window-management, and keycap tests remain green.

- [ ] **Step 8: Commit the Settings slice**

```bash
git -C /Users/woosublee/Documents/dev/zap add -- \
  Sources/ZapApp/Views/ShortcutRecorderView.swift \
  Sources/ZapApp/Views/SettingsView.swift \
  Tests/ZapAppTests/ShortcutRecorderViewTests.swift \
  Tests/ZapAppTests/SettingsShortcutControlsUITests.swift

git -C /Users/woosublee/Documents/dev/zap commit \
  -m "feat: add active app shortcut controls settings" \
  -m "Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: Run complete regression, build the development app, and verify the Carbon boundary

**Files:**
- Verify only; no source changes are expected.
- If verification exposes a defect, return to the task that owns the behavior, add a failing regression test there, implement the minimum fix, rerun its focused tests, and make a separate fix commit.

**Interfaces:**
- Verifies all interfaces produced in Tasks 1–5.
- Does not add a new API.

- [ ] **Step 1: Run every focused feature test**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test --filter ActiveApplicationToggleShortcutTests
swift test --filter GlobalHotKeyRegistrationPlanTests
swift test --filter GlobalHotKeyDispatchMappingTests
swift test --filter ZapAppModelHotKeyIntegrationTests
swift test --filter ShortcutRecorderViewTests
swift test --filter SettingsShortcutControlsUITests
swift test --filter SettingsWindowManagementUITests
```

Expected: every command exits successfully with zero failures.

- [ ] **Step 2: Run the complete Swift test suite**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test
```

Expected: all `ZapCoreTests` and `ZapAppTests` pass. Existing Dock, Finder, Manual, Window Management, menu bar Pause, Settings, Sparkle, Accessibility, and release workflow tests remain green.

- [ ] **Step 3: Build the development app with ad-hoc signing**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
make dev-build CODESIGN_IDENTITY=-
```

Expected:

- Swift build completes;
- `/tmp/zap-bundles/dev/Zap dev.app` is created;
- Sparkle is embedded;
- ad-hoc codesigning completes without an error.

- [ ] **Step 4: Launch the development app**

Run:

```bash
open "/tmp/zap-bundles/dev/Zap dev.app"
```

Expected: `Zap dev` launches as a menu bar app without a Carbon registration crash.

- [ ] **Step 5: Verify initial unset and recording behavior**

Manual sequence:

1. Open `Settings > General`.
2. Confirm `Shortcut Controls` appears after `Permissions` and before `Behavior`.
3. Confirm `Toggle Zap for Current App` initially displays the existing `Not set` keycap.
4. Click the keycap.
5. Press a modifier plus key, such as `⌃⌥T`.
6. Close and reopen Settings.
7. Quit and relaunch the development app.

Expected:

- the recorder uses the control-specific copy;
- modifier-free input shows `Select at least one modifier key.`;
- Escape cancels without changing the shortcut;
- `⌃⌥T` appears in the keycap;
- the shortcut survives app relaunch.

- [ ] **Step 6: Verify app-disabled control-only behavior**

Manual sequence:

1. Focus an arbitrary app such as Safari.
2. Press the configured control shortcut.
3. Try a configured Dock, Finder, Manual, and Window Management shortcut.
4. Press the same control shortcut again.
5. Retry the regular shortcuts.

Expected:

- the first control press adds Safari to the existing disabled-app state;
- regular Zap shortcuts stop working in Safari;
- the control shortcut remains registered and receives the second press;
- the second press removes Safari from the disabled list;
- regular shortcuts are restored immediately.

- [ ] **Step 7: Verify app switching preserves the existing exclusion behavior**

Manual sequence:

1. Disable Zap while Safari is active.
2. Switch to Notes or another non-disabled app.
3. Verify regular shortcuts work.
4. Switch back to Safari.
5. Verify regular shortcuts are disabled while the control shortcut still works.

Expected: registration follows the active app’s existing disabled status without losing the control shortcut.

- [ ] **Step 8: Verify global Pause releases all hotkeys**

Manual sequence:

1. Choose menu bar `Pause Shortcuts > Until Resumed`.
2. Press the configured current-app toggle shortcut.
3. Verify it does not change the disabled state.
4. Choose `Resume Shortcuts`.
5. Press the control shortcut again.

Expected:

- global Pause unregisters both regular and control hotkeys;
- the control shortcut cannot resume global Pause;
- menu bar Resume restores registration;
- after Resume, the control shortcut works again.

- [ ] **Step 9: Verify conflict priority and Clear**

Manual sequence:

1. Configure the control shortcut to the same combination as a Dock, Finder, Manual, or Window shortcut.
2. Observe Settings registration errors.
3. Verify the control shortcut still toggles the current app.
4. Click `Clear`.
5. Verify the keycap returns to `Not set`.
6. If the current app is disabled, use the menu bar Enable action to restore it.

Expected:

- the control owner wins internal conflicts;
- lower-priority conflicts use existing planner error text;
- Carbon registration failures appear through `registrationError`;
- Clear removes the persisted control shortcut and releases ID `3000`;
- menu bar Disable/Enable remains available even without a configured control shortcut.

- [ ] **Step 10: Run the complete suite again after manual verification**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
swift test
```

Expected: PASS after UserDefaults and manual app activity.

- [ ] **Step 11: Inspect the implementation diff**

Run:

```bash
git -C /Users/woosublee/Documents/dev/zap status --short
git -C /Users/woosublee/Documents/dev/zap diff --check
git -C /Users/woosublee/Documents/dev/zap log -5 --oneline
```

Expected:

- `git diff --check` reports no whitespace errors;
- no build artifacts under `.build`, `/tmp/zap-bundles`, or `.sparkle-tools` are staged;
- commits are limited to the model, planner/service, runtime integration, and Settings slices described above.

No final empty commit is required. If no fixes were needed during verification, stop after confirming the working tree contains only intentionally uncommitted documentation, if any.

---

## Requirement Coverage Matrix

| Design requirement | Implementation/test coverage |
|---|---|
| Initial shortcut is unset | Task 1 model test; Task 4 initial model test; Task 5 keycap UI |
| Record and persist shortcut | Task 4 set/restore test; Task 5 recorder wiring |
| Clear shortcut | Task 4 Clear persistence test; Task 5 Clear UI test |
| Corrupt value recovers to unset | Task 4 corrupt JSON test |
| Highest-priority owner | Task 2 owner-first and conflict tests |
| Fixed, non-overlapping Carbon ID | Task 2 ID `3000`; Task 3 dispatch test |
| Control-only plan | Task 2 scope test |
| Disabled app keeps only control | Task 4 runtime scope test; Task 6 manual verification |
| Second press restores regular shortcuts | Task 4 second-toggle test; Task 6 manual verification |
| Global Pause unregisters all | Task 4 Pause test; Task 6 manual verification |
| App switching keeps exclusions | Updated Task 4 activation integration test; Task 6 manual verification |
| Missing bundle identifier is ignored | Task 4 nil active-application callback test |
| Existing menu and keyboard share mutation | Task 3 callback test calls existing `toggleHotKeysForActiveApplication()` |
| Existing conflict/error behavior | Task 2 planner assertions; Task 3 Carbon failure assertion |
| General > Shortcut Controls placement | Task 5 source-structure test |
| Existing keycap unset presentation | Existing `ZapDesignSystemTests` plus Task 5 |
| Existing modifier/Escape behavior | Existing and extended `ShortcutRecorderViewTests` |
| No new sidebar page | Task 5 changes only `generalSection`; existing Settings mode tests remain green |

### Critical Files for Implementation

- `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Services/GlobalHotKeyService.swift`
- `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/ViewModels/ZapAppModel.swift`
- `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Models/ActiveApplicationToggleShortcut.swift`
- `/Users/woosublee/Documents/dev/zap/Sources/ZapApp/Views/SettingsView.swift`
- `/Users/woosublee/Documents/dev/zap/Tests/ZapAppTests/ZapAppModelHotKeyIntegrationTests.swift`