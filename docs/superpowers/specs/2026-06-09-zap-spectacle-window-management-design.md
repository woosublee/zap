# Zap + Spectacle Window Management 통합 설계

작성일: 2026-06-09

## 1. 배경

Zap은 SwiftPM 기반 macOS 메뉴바 유틸리티이며, 현재 핵심 기능은 Dock 앱, Finder, 수동 앱 단축키를 통해 앱을 실행하거나 활성화하는 것이다. sibling 프로젝트인 `spectacle`은 Objective-C/AppKit 기반 window management 앱이며, Carbon 전역 단축키와 Accessibility API를 사용해 현재 활성 창을 정렬한다.

이번 작업의 목표는 Spectacle/Spectra 앱 전체를 Zap에 병합하는 것이 아니라, Spectacle의 주요 window management 기능을 Zap의 Swift 구조에 맞게 흡수하는 것이다. Zap의 앱 이름, bundle id, Sparkle 업데이트, 배포/서명 흐름은 유지한다.

Snap은 Zap의 이전 이름이다. 현재 repo에 있는 untracked `SnapApp`, `SnapCore`, `SnapAppTests`, `SnapCoreTests` 디렉터리는 rename 과정의 잔재로 보고, 이번 설계의 대상은 tracked `ZapApp`, `ZapCore`, `ZapAppTests`, `ZapCoreTests` 경로다. Snap 잔재는 사용자 승인 없이 삭제하지 않는다.

## 2. 목표

- Zap에 Spectacle의 주요 window management 기능을 추가한다.
- 기존 Zap의 Dock/Finder/manual app shortcut 기능을 유지한다.
- Spectacle의 기본 window action 단축키를 Zap의 기본값으로 제공한다.
- Settings에서 window action shortcut을 표시, 수정, 비활성화, reset할 수 있게 한다.
- Accessibility 권한 상태를 표시하고 권한 안내/설정 이동 UX를 제공한다.
- macOS Accessibility API로 frontmost window를 이동/크기 변경한다.
- 다중 모니터, thirds, larger/smaller, undo/redo를 포함한다.
- 계산 로직과 screen detection은 Swift pure logic으로 작성하고 XCTest로 검증한다.
- 실제 창 이동은 mock 기반 테스트와 수동 검증을 병행한다.

## 3. 비목표

- Spectacle/Spectra 앱 shell 전체를 가져오지 않는다.
- Spectacle의 `Info.plist`, bundle id, appcast, Sparkle 설정, release script를 가져오지 않는다.
- Spectacle의 XIB 기반 Preferences UI를 그대로 가져오지 않는다.
- Spectacle의 Carthage/Specta/Expecta/OCMockito 테스트 스택을 가져오지 않는다.
- 기존 Spectacle/Spectra 사용자 설정 migration은 이번 범위에서 제외한다.
- per-app disable, blacklist, disable-for-one-hour 기능은 이번 1차 통합의 필수 범위에서 제외한다.
- localization 리소스 이식은 이번 범위에서 제외한다.

## 4. 포함 기능

### 4.1 Window actions

다음 action을 Zap window management 기능으로 포함한다.

- Center
- Fullscreen
- Left Half
- Right Half
- Top Half
- Bottom Half
- Upper Left
- Upper Right
- Lower Left
- Lower Right
- Next Display
- Previous Display
- Next Third
- Previous Third
- Larger
- Smaller
- Undo
- Redo

### 4.2 기본 단축키

Spectacle 기본 단축키를 Zap의 window management 기본값으로 사용한다.

| Action | Default Shortcut |
| --- | --- |
| Center | `⌥⌘C` |
| Fullscreen | `⌥⌘F` |
| Left Half | `⌥⌘←` |
| Right Half | `⌥⌘→` |
| Top Half | `⌥⌘↑` |
| Bottom Half | `⌥⌘↓` |
| Upper Left | `⌃⌘←` |
| Lower Left | `⌃⇧⌘←` |
| Upper Right | `⌃⌘→` |
| Lower Right | `⌃⇧⌘→` |
| Next Display | `⌃⌥⌘→` |
| Previous Display | `⌃⌥⌘←` |
| Next Third | `⌃⌥→` |
| Previous Third | `⌃⌥←` |
| Larger | `⌃⌥⇧→` |
| Smaller | `⌃⌥⇧←` |
| Undo | `⌥⌘Z` |
| Redo | `⌥⇧⌘Z` |

기존 Zap 기본 단축키는 유지한다.

- Dock: `⌥1`–`⌥9`
- Finder: `⌥` + physical `₩`/`` ` `` variants
- Manual app shortcut: 사용자 지정

모든 shortcut은 단일 `GlobalHotKeyService` registry에서 충돌 검사한다.

## 5. 아키텍처

Zap의 기존 앱 실행 단축키 기능은 유지하고, window management를 별도 도메인으로 추가한다.

```text
ZapApp
├─ ZapAppModel
│  ├─ Dock shortcut orchestration
│  ├─ Finder shortcut orchestration
│  ├─ Manual app shortcut orchestration
│  └─ WindowManagementModel 연결
│
├─ GlobalHotKeyService
│  ├─ Dock hotkeys
│  ├─ Finder hotkeys
│  ├─ Manual app hotkeys
│  └─ Window action hotkeys
│
├─ WindowManagementModel
│  ├─ window action shortcut 상태
│  ├─ Accessibility 권한 상태
│  ├─ action 실행 요청
│  └─ Settings/MenuBar 표시용 상태
│
├─ AccessibilityPermissionService
│  ├─ AX 권한 확인
│  ├─ 권한 요청 prompt
│  └─ System Settings 열기
│
├─ AccessibilityWindowService
│  ├─ frontmost window 조회
│  ├─ window rect 읽기
│  ├─ window rect 쓰기
│  └─ sheet/system dialog 제외
│
└─ SettingsView / MenuBarView
   ├─ Window Management 섹션
   ├─ shortcut 표시/수정/초기화
   └─ 권한 안내 UI

ZapCore
├─ WindowAction
├─ WindowShortcut
├─ WindowShortcutDefaults
├─ WindowPositionCalculator
├─ ScreenDetector
└─ WindowHistory
```

### 5.1 Target 구조

새 SwiftPM target을 만들지 않고 `ZapCore`와 `ZapApp`을 확장한다.

- `ZapCore`: macOS API에 의존하지 않는 모델과 pure 계산 로직
- `ZapApp`: AppKit, Carbon, Accessibility, UserDefaults, SwiftUI 의존 로직

필요 시 `Package.swift`의 `ZapApp` linker settings에 `ApplicationServices`를 추가한다. JavaScriptCore는 사용하지 않는 것을 기본 방향으로 한다.

## 6. ZapCore 설계

### 6.1 `WindowAction`

Spectacle action을 Swift enum으로 정의한다.

```swift
enum WindowAction: String, CaseIterable, Codable, Identifiable {
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
}
```

역할:

- Settings 표시 이름
- 기본 shortcut lookup
- calculation mapping
- action grouping

### 6.2 `WindowShortcut`

Window action별 shortcut value object를 둔다.

```swift
struct WindowShortcut: Codable, Equatable, Identifiable {
    var action: WindowAction
    var keyCode: UInt32?
    var keyDisplayName: String?
    var modifiers: Set<ShortcutModifier>
    var isEnabled: Bool
}
```

`ManualShortcut`과 형태는 비슷하지만 대상이 앱이 아니라 `WindowAction`이다.

### 6.3 `WindowShortcutDefaults`

Spectacle 기본 단축키를 Swift 값으로 정의한다. Arrow key, `C`, `F`, `Z` 등은 Carbon virtual key code 기준으로 저장한다.

### 6.4 `WindowPositionCalculator`

창 rect 계산을 pure function으로 구현한다.

```swift
struct WindowCalculationInput {
    let windowFrame: CGRect
    let sourceVisibleFrame: CGRect
    let destinationVisibleFrame: CGRect
    let action: WindowAction
}

struct WindowCalculationResult {
    let frame: CGRect
    let resolvedAction: WindowAction
}
```

지원 계산:

- fullscreen
- center
- halves
- corners
- next/previous third
- larger/smaller
- display 이동 시 destination visible frame 기준 재배치

Undo/redo는 calculator가 아니라 `WindowHistory`가 처리한다.

### 6.5 `ScreenDetector`

`NSScreen` 없이 테스트 가능한 display model을 사용한다.

```swift
struct DisplayFrame: Equatable {
    let frame: CGRect
    let visibleFrame: CGRect
    let isMain: Bool
}
```

역할:

- 현재 window가 속한 source display 찾기
- next/previous display 찾기
- window/display overlap 계산
- source/destination visible frame 반환

`NSScreen` → `DisplayFrame` 변환은 `ZapApp`에서 담당한다.

### 6.6 `WindowHistory`

Undo/redo용 pure data structure를 둔다.

```swift
struct WindowHistoryItem: Equatable {
    let applicationIdentifier: String
    let windowFrame: CGRect
}
```

원칙:

- 일반 action 실행 전 현재 frame을 기록한다.
- action 성공 후 target frame을 history 상태에 반영한다.
- frontmost app 기준으로 history를 분리한다.
- stale `AXUIElement` reference를 오래 들고 있지 않도록 history에는 frame과 app identifier 중심 데이터를 저장한다.
- 1차 구현에서는 undo/redo가 현재 frontmost window에 적용된다.

## 7. ZapApp 설계

### 7.1 `AccessibilityPermissionService`

역할:

- `AXIsProcessTrusted()`로 권한 확인
- `AXIsProcessTrustedWithOptions(...)`로 사용자 prompt 요청
- System Settings 접근성 설정 열기

테스트 가능하도록 protocol을 둔다.

```swift
protocol AccessibilityPermissionChecking {
    var isTrusted: Bool { get }
    func requestPrompt()
}
```

### 7.2 `AccessibilityWindowService`

Spectacle의 `SpectacleAccessibilityElement`를 Swift로 재구성한다.

역할:

- frontmost app의 focused window 조회
- role/subrole 검사
- `kAXPositionAttribute`, `kAXSizeAttribute` 읽기
- `kAXPositionAttribute`, `kAXSizeAttribute` 쓰기
- 좌표계 normalize
- `AXError`를 domain error로 변환

테스트 가능하도록 protocol을 둔다.

```swift
protocol AccessibilityWindowControlling {
    func frontmostWindow() throws -> AccessibilityWindow
    func frame(of window: AccessibilityWindow) throws -> CGRect
    func setFrame(_ frame: CGRect, of window: AccessibilityWindow) throws
}
```

### 7.3 `WindowManagementService`

하나의 window action을 실행하는 application service다.

흐름:

1. Accessibility 권한 확인
2. frontmost window 조회
3. sheet/system dialog 여부 확인
4. 현재 window frame 읽기
5. `NSScreen.screens`를 `DisplayFrame`으로 변환
6. `ScreenDetector`로 source/destination display 결정
7. `WindowPositionCalculator`로 target frame 계산
8. history 기록
9. `AccessibilityWindowService`로 target frame 적용
10. 실패 시 beep 또는 model error 업데이트

### 7.4 `WindowManagementModel`

Settings와 hotkey callback이 바라보는 observable model이다.

상태:

- `windowShortcuts`
- `accessibilityTrusted`
- `windowManagementError`
- `shortcutRegistrationError`
- `isWindowManagementEnabled`

메서드:

- `perform(action:)`
- `setShortcut(action:keyCode:keyDisplayName:modifiers:)`
- `setShortcutEnabled(action:isEnabled:)`
- `resetShortcutsToDefaults()`
- `refreshAccessibilityPermission()`
- `openAccessibilitySettings()`

### 7.5 Settings UI

`SettingsView`에 Window Management mode 또는 section을 추가한다. 기능 규모상 별도 mode/tab이 적합하다.

예상 신규 view:

```text
Sources/ZapApp/Views/WindowManagementSettingsView.swift
Sources/ZapApp/Views/WindowShortcutRowView.swift
```

기능:

- action별 shortcut 표시
- shortcut recording
- shortcut 비활성화
- reset to defaults
- conflict/registration error 표시
- Accessibility 권한 상태와 설정 열기 버튼 표시

### 7.6 `GlobalHotKeyService` 확장

`GlobalHotKeyService`는 하나만 유지한다. Spectacle의 별도 shortcut manager는 붙이지 않는다.

현재 register signature를 확장한다.

```swift
func register(
    modifiers: Set<ShortcutModifier>,
    finderShortcutEnabled: Bool,
    manualShortcuts: [ManualShortcut],
    windowShortcuts: [WindowShortcut]
) -> String?
```

callback을 추가한다.

```swift
private let onWindowHotKey: (WindowAction) -> Void
```

ID namespace:

- Dock: `1...9`
- Finder: `100...103`
- Manual: `1000...`
- Window: `2000...`

모든 등록 대상은 같은 `HotKeyCombo` set에서 충돌 검사한다.

## 8. 데이터 흐름

### 8.1 Hotkey 실행 흐름

```text
사용자 단축키 입력
↓
Carbon Event Handler
↓
GlobalHotKeyService
↓
WindowAction 식별
↓
ZapAppModel / WindowManagementModel
↓
WindowManagementService.perform(action:)
↓
Accessibility 권한 확인
↓
frontmost window 조회
↓
screen/source/destination 계산
↓
target frame 계산
↓
AX로 window frame 적용
↓
history 기록 / 오류 표시
```

### 8.2 Settings shortcut 변경 흐름

```text
SettingsView
↓
WindowManagementSettingsView
↓
WindowShortcutRowView
↓
ShortcutRecorderView
↓
WindowManagementModel.setShortcut(...)
↓
UserDefaults 저장
↓
ZapAppModel.registerHotKeys()
↓
GlobalHotKeyService.register(...)
↓
충돌/등록 실패 결과 반영
```

## 9. 오류 처리

### 9.1 Shortcut registration error

예:

- 이미 등록된 shortcut과 충돌
- macOS가 hotkey 등록 거부
- modifier 없는 shortcut
- 동일 combo 중복

처리:

- 등록 가능한 shortcut은 계속 등록한다.
- 충돌 shortcut은 등록하지 않는다.
- Settings 상단 또는 각 row에 오류를 표시한다.
- 현재 `String?` 반환 구조를 유지하거나, 구현 중 필요하면 구조화된 error로 확장한다.

### 9.2 Accessibility permission error

예:

- 권한 없음
- TCC에서 접근 불가

처리:

- Settings에 warning 표시
- hotkey 실행 시 beep
- System Settings 열기 버튼 제공
- 권한 없는 상태에서 prompt를 반복 표시하지 않는다.

### 9.3 Frontmost window error

예:

- frontmost app 없음
- focused window 없음
- sheet/system dialog
- window rect 읽기 실패
- window frame 쓰기 실패

처리:

- 기본 feedback은 `NSSound.beep()`
- 최근 오류를 model에 짧게 저장해 UI 표시 가능하게 한다.
- sheet/system dialog는 조작하지 않는다.

### 9.4 Calculation error

예:

- source display 찾기 실패
- destination display 찾기 실패
- visible frame invalid
- 계산 결과가 기존 frame과 동일
- 지원하지 않는 action

처리:

- target frame을 적용하지 않는다.
- history를 기록하지 않는다.
- beep 또는 model error로 사용자에게 알린다.

## 10. Window mover 보정

Spectacle의 mover chain 개념은 포함하되 구현 checkpoint를 나눈다.

1. Standard mover
   - target frame을 AX로 size/position 적용
   - 적용 후 실제 frame을 다시 읽어 차이를 확인
2. Best-effort 보정
   - visibleFrame 밖으로 밀려난 경우 가능한 범위에서 보정
   - 앱이 최소 크기를 강제한 경우 가능한 target에 근접
3. Quantized 보정
   - Terminal/iTerm류 row/column 단위 resizing 차이를 보정

## 11. 테스트 전략

### 11.1 `ZapCoreTests`

추가 후보:

```text
Tests/ZapCoreTests/WindowActionTests.swift
Tests/ZapCoreTests/WindowShortcutDefaultsTests.swift
Tests/ZapCoreTests/WindowPositionCalculatorTests.swift
Tests/ZapCoreTests/ScreenDetectorTests.swift
Tests/ZapCoreTests/WindowHistoryTests.swift
```

우선순위:

1. `WindowShortcutDefaults`
2. `WindowPositionCalculator`
3. `ScreenDetector`
4. `WindowHistory`
5. shortcut conflict/id mapping

### 11.2 Spectacle 테스트 이식

Spectacle의 Objective-C spec 중 계산 관련 테스트를 Swift XCTest로 옮긴다.

우선 이식 대상:

- center
- fullscreen
- left/right/top/bottom half
- upper/lower corners
- next/previous third
- next/previous display
- larger/smaller
- screen detector

### 11.3 `ZapAppTests`

실제 AX API는 직접 테스트하지 않고 mock/protocol 기반으로 테스트한다.

추가 후보:

```text
Tests/ZapAppTests/WindowManagementModelTests.swift
Tests/ZapAppTests/AccessibilityPermissionServiceTests.swift
Tests/ZapAppTests/WindowShortcutRegistrationTests.swift
```

테스트 대상:

- 권한 없을 때 action 실패
- focused window 없음
- calculation 실패
- action 성공 시 service 호출 순서
- shortcut 변경 후 registration 요청
- reset defaults

### 11.4 수동 검증

실제 창 이동은 macOS 런타임 검증이 필요하다.

체크리스트:

- Accessibility 권한 없는 상태
- 권한 부여 후 Zap 재실행 또는 상태 refresh
- Finder, Chrome, Terminal, iTerm, Notes 등 앱별 창 이동
- 다중 모니터 next/previous display
- fullscreen/halves/corners/thirds
- undo/redo
- 기존 Dock shortcut `⌥1`–`⌥9`
- Finder shortcut
- manual app shortcut
- Sparkle/update settings 영향 없음

## 12. 예상 변경 파일

### 12.1 신규 파일 후보

```text
Sources/ZapCore/WindowAction.swift
Sources/ZapCore/WindowShortcut.swift
Sources/ZapCore/WindowShortcutDefaults.swift
Sources/ZapCore/WindowGeometry.swift
Sources/ZapCore/WindowPositionCalculator.swift
Sources/ZapCore/ScreenDetector.swift
Sources/ZapCore/WindowHistory.swift

Sources/ZapApp/Models/WindowShortcutPresentation.swift
Sources/ZapApp/Services/AccessibilityPermissionService.swift
Sources/ZapApp/Services/AccessibilityWindowService.swift
Sources/ZapApp/Services/WindowManagementService.swift
Sources/ZapApp/Services/SystemSettingsOpener.swift
Sources/ZapApp/ViewModels/WindowManagementModel.swift
Sources/ZapApp/Views/WindowManagementSettingsView.swift
Sources/ZapApp/Views/WindowShortcutRowView.swift

Tests/ZapCoreTests/WindowActionTests.swift
Tests/ZapCoreTests/WindowShortcutDefaultsTests.swift
Tests/ZapCoreTests/WindowPositionCalculatorTests.swift
Tests/ZapCoreTests/ScreenDetectorTests.swift
Tests/ZapCoreTests/WindowHistoryTests.swift
Tests/ZapAppTests/WindowManagementModelTests.swift
Tests/ZapAppTests/WindowShortcutRegistrationTests.swift
```

### 12.2 수정 파일 후보

```text
Package.swift
Sources/ZapApp/Services/GlobalHotKeyService.swift
Sources/ZapApp/ViewModels/ZapAppModel.swift
Sources/ZapApp/Views/SettingsView.swift
Sources/ZapApp/Views/ShortcutRecorderView.swift
Sources/ZapApp/Views/MenuBarView.swift
Tests/ZapAppTests/* existing tests as needed
Tests/ZapCoreTests/* existing tests as needed
```

## 13. 위험과 완화책

### 13.1 Accessibility 좌표계

위험: AppKit screen coordinates와 Accessibility coordinates가 달라 창이 잘못 이동할 수 있다.

완화:

- Spectacle의 coordinate normalization을 Swift로 재검토한다.
- 다중 모니터 fixture를 XCTest로 만든다.
- 실제 앱에서 수동 검증한다.

### 13.2 Hotkey 충돌

위험: Dock/Finder/manual/window shortcut이 충돌할 수 있다.

완화:

- 단일 `GlobalHotKeyService` registry에서 모든 combo를 검사한다.
- ID namespace를 명확히 분리한다.
- Settings에서 충돌을 표시한다.

### 13.3 앱별 window constraints

위험: Terminal/iTerm처럼 창 크기가 grid 단위로만 바뀌거나, 앱이 minimum size를 강제할 수 있다.

완화:

- Standard mover 후 실제 frame을 다시 읽는다.
- best-effort 보정과 quantized 보정을 단계적으로 적용한다.
- 앱별 수동 검증 체크리스트를 유지한다.

### 13.4 구현 범위 과대화

위험: Spectacle의 오래된 UI, migration, blacklist까지 가져오면 범위가 지나치게 커진다.

완화:

- 이번 범위는 주요 window actions, shortcut 설정, 권한 UX, undo/redo, 다중 모니터로 제한한다.
- legacy migration, per-app disable, localization은 제외한다.

### 13.5 기존 Zap release flow 영향

위험: Sparkle/release/signing 관련 최근 안정화 작업이 깨질 수 있다.

완화:

- Spectacle의 Sparkle/release 설정은 가져오지 않는다.
- `Makefile`, `Info.plist`, `UpdateService` 변경은 필요한 경우에만 최소화한다.
- 기존 update tests를 계속 통과시킨다.

## 14. 완료 기준

- Zap 앱 이름, bundle id, Sparkle/update/release 설정이 유지된다.
- 기존 Dock/Finder/manual app shortcut 기능이 유지된다.
- Settings에 Window Management 영역이 생긴다.
- Spectacle 주요 window actions가 기본 shortcut으로 등록된다.
- shortcut 수정, 비활성화, reset이 가능하다.
- Accessibility 권한 안내가 제공된다.
- 권한 부여 후 단축키로 frontmost window를 이동할 수 있다.
- 다중 모니터와 undo/redo가 동작한다.
- `swift test`가 통과한다.
- 실제 앱 실행 수동 검증 체크리스트를 수행한다.
- untracked Snap 잔재는 사용자 승인 없이 삭제하지 않는다.
