# Zap 단축키 실행 HUD 설계

## 배경

Zap의 글로벌 단축키는 앱을 전환하거나 현재 앱에서 Zap 단축키를 비활성화할 수 있지만, 단축키 입력이 실제로 처리되었는지 알려 주는 일시적 피드백이 없다. 앱 전환이 늦거나 대상 앱이 이미 활성 상태이면 사용자는 입력 성공 여부를 판단하기 어렵다.

Spectacle은 Dock 앱 호출 단축키를 사용할 때 화면 중앙에 해당 앱 아이콘을 잠시 표시했다. Zap도 같은 수준의 짧고 조용한 HUD를 제공하되, 모든 단축키에 적용하지 않고 앱 호출과 앱별 Enable/Disable처럼 결과 확인이 필요한 동작에만 제한한다.

## 목표

1. Automatic Dock 단축키로 앱 활성화 또는 실행에 성공하면 현재 작업 화면 중앙에 해당 앱 아이콘 HUD를 표시한다.
2. Finder global shortcut으로 Finder 활성화 또는 실행에 성공하면 같은 화면에 Finder 아이콘 HUD를 표시한다.
3. 현재 앱에서 Zap 단축키를 비활성화하면 앱 아이콘과 빨간 `−` badge를 표시한다.
4. 현재 앱에서 Zap 단축키를 다시 활성화하면 앱 아이콘과 초록 `✓` badge를 표시한다.
5. 단축키 ID 인식이 아니라 실제 action 성공 이후에만 HUD를 표시한다.
6. HUD가 대상 앱의 활성화나 사용자 입력 focus를 방해하지 않게 한다.
7. 빠르게 나타나 한 번만 작게 반동하고, 선명한 상태를 충분히 유지한 뒤 opacity만 빠르게 사라지는 비차단 피드백으로 구현한다.
8. Reduce Motion, Reduce Transparency, VoiceOver를 고려한다.

## 비목표

- Manual 앱 단축키 HUD
- Window Management 단축키 HUD
- 향후 같은 앱의 window cycle 동작 HUD
- 메뉴 클릭으로 실행한 Dock 앱, Finder 또는 앱별 Enable/Disable HUD
- 전역 Pause/Resume HUD
- 실패 상태를 표현하는 오류 HUD
- 앱 이름이나 상태 문구를 화면에 표시하는 확장형 HUD
- 지속적인 Pause 또는 앱별 disabled 상태 표시 대체
- window switcher, thumbnail overlay, action history

## 사용자 동작

### Automatic Dock 앱 호출

1. 사용자가 Automatic Dock 단축키를 누른다.
2. Zap은 입력 직전 시스템 전역 keyboard focus를 포함하는 최상위 window가 속한 화면을 보관한다.
3. 해당 번호의 `DockItem`을 한 번 resolve한다.
4. 대상 앱이 실행 중이면 활성화하고, 실행 중이 아니면 새로 실행한다.
5. 활성화 또는 실행 성공을 확인한 후 같은 `DockItem`의 application URL과 bundle identifier를 HUD payload에 복사한다.
6. Presenter는 payload로 실제 앱 아이콘을 resolve하고 새 HUD lifecycle을 시작한다.

대상 Dock slot이 없으면 hotkey wrapper가 beep를 정확히 한 번 내고 HUD를 표시하지 않는다. 앱 활성화·실행에 실패하면 launcher가 기존 beep를 정확히 한 번 내고 `.failed`를 반환하며, 호출자는 beep를 추가하지 않고 HUD도 표시하지 않는다.

### Finder global shortcut

1. 사용자가 Finder global shortcut을 누른다.
2. Zap은 다른 HUD 대상 hotkey와 같은 generation을 발급하고 입력 직전 대상 화면을 보관한다.
3. Finder가 실행 중이면 `.activateAllWindows`와 `.activateIgnoringOtherApps`로 활성화를 시도한다.
4. Activation이 성공하면 기존 reopen event를 보내고 `.activated`를 반환한다.
5. Finder가 실행 중이 아니면 `NSWorkspace.openApplication` completion에서 error가 없고 running application이 반환된 경우에만 `.launched`를 반환한다.
6. `.activated` 또는 `.launched`인 최신 요청만 `Finder`, `com.apple.finder` metadata로 badge 없는 Finder icon HUD를 표시한다.

Finder activation 또는 launch가 실패하면 launcher가 beep를 정확히 한 번 내고 HUD를 표시하지 않는다. 메뉴에서 Finder를 호출할 때는 같은 launcher를 사용하되 outcome을 무시하고 HUD presenter를 호출하지 않는다.

### 현재 앱에서 Zap 비활성화

1. 사용자가 현재 앱 토글 단축키를 누른다.
2. Zap은 입력 직전 시스템 전역 keyboard focus를 포함하는 최상위 window의 화면과 현재 앱을 확인한다.
3. 기존 `toggleHotKeysForActiveApplication()` mutation 경로로 앱별 disabled 상태를 변경한다.
4. 앱이 disabled 상태가 되면 앱 아이콘 오른쪽 아래에 빨간 `−` badge를 붙인 HUD를 표시한다.
5. 같은 단축키를 다시 눌러 enabled 상태가 되면 초록 `✓` badge HUD를 표시한다.

현재 앱을 확인할 수 없으면 상태를 변경하지 않고 beep나 HUD도 표시하지 않는다.

## 시각 설계

HUD는 승인된 아이콘 중심 A안을 사용한다.

- 보이는 HUD card 크기: 132×132pt
- panel frame: card 외곽 shadow inset을 포함하며 card보다 클 수 있음
- corner radius: 32pt
- 위치: 선택된 화면 전체 frame의 정중앙
- 배경: 어두운 반투명 material
- 외곽선: top-leading white highlight에서 bottom-trailing의 옅은 blue/white로 이어지는 얇은 gradient glass stroke
- 내부 경계: card 안쪽 4pt 지점의 낮은 opacity inner highlight
- shadow: 화면 배경과 분리되는 부드러운 외곽 shadow
- 앱 아이콘: 76×76pt
- 앱 활성화 또는 실행: badge 없음
- 앱별 Disable: 오른쪽 아래 빨간 원형 `−` badge
- 앱별 Enable: 오른쪽 아래 초록 원형 `✓` badge
- 화면에 앱 이름이나 상태 문구를 표시하지 않음

색상만으로 상태를 구분하지 않도록 Disable과 Enable은 서로 다른 기호를 함께 사용한다. 앱 아이콘을 해석할 수 없으면 macOS 기본 application icon을 사용한다.

## 표시 시간과 animation

기본 animation은 비교 prototype의 C(Spring overshoot)를 production에 맞게 완화한 모션을 사용한다.

1. opacity entry: 0.10초 ease-out
2. card 전체 scale: `0.86 → 1.0`, `response: 0.24`, `dampingFraction: 0.72`, `blendDuration: 0` spring
3. spring 안정 시간: 약 0.36초
4. 안정된 선명 상태 유지: 1.20초
5. 요청 후 1.56초에 opacity-only fade-out 시작
6. fade-out: 0.09초 ease-out
7. 요청 후 1.65초에 panel 숨김

Spring은 card, icon, badge 전체에 적용하고 한 번만 작게 반동한 뒤 즉시 안정되어야 한다. 퇴장 시 scale, blur, 잔상 layer는 변경하거나 추가하지 않는다. Glass outer stroke와 inner highlight도 고정된 상태로 유지한다.

빠르게 연속 입력하면 기존 dismiss 작업을 취소하고 새 payload와 대상 화면으로 숨김 없이 즉시 교체한다. 이미 panel이 표시 중이면 entry animation은 재시작하지 않고 현재 opacity와 scale을 유지하며, fade-out 시작 시점과 hide deadline만 새 요청을 기준으로 다시 계산한다. 새 요청의 대상 화면이 바뀌면 panel도 새 화면 중앙으로 이동한다. Timing 테스트의 허용 오차는 ±0.05초다.

Reduce Motion이 활성화되면 scale/spring을 제거한다. 0.10초 opacity entry 후 1.20초 유지하고 요청 후 1.30초에 0.09초 opacity-only fade-out을 시작해 1.39초에 panel을 숨긴다. Reduce Transparency가 활성화되면 반투명 material 대신 불투명도가 높은 어두운 배경을 사용하며 glass 경계 표현은 유지한다.

## 실행 결과 모델

현재 `AppLaunching`의 동기 `Void` 계약으로는 비동기 app open completion까지 확인한 실제 action 결과를 HUD 정책에 전달할 수 없다. 앱 실행 계층은 completion 기반의 명시적 비동기 계약을 사용한다.

```swift
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
```

- 주입된 실행 중 앱 activation operation은 `Bool`을 반환한다. `true`는 `.activated`, `false`는 `.failed`다.
- `NSWorkspace.openApplication` completion에서 error가 없고 running application이 반환된 경우에만 `.launched`다.
- Activation 또는 open completion 실패는 `.failed`다.
- Finder running activation은 성공했을 때만 기존 reopen event를 보낸다.
- Dock과 Finder completion 및 실패 beep는 method-local exactly-once guard를 통과한다.
- Completion은 main actor에서 정확히 한 번 전달한다.

`AppLaunching`은 Dock과 Finder activation/open 실패 beep의 유일한 owner다. 실패 시 beep를 정확히 한 번 낸 뒤 `.failed` completion을 전달하며, hotkey와 menu caller는 `.failed`에 대해 추가 beep를 내지 않는다. 호출자는 `.activated`와 `.launched`일 때만 HUD를 요청한다. Dock slot 자체가 없는 경우는 launcher를 호출하지 않으므로 hotkey wrapper가 beep를 정확히 한 번 담당한다. Manual shortcut과 Finder menu action은 같은 비동기 launcher를 사용하되 outcome을 무시하고 HUD presenter를 호출하지 않는다.

앱별 상태 mutation도 입력 시점의 단일 앱 snapshot과 실제 변경 결과를 사용해야 한다.

```swift
enum ActiveApplicationToggleOutcome: Equatable {
    case disabled(ActiveApplication)
    case enabled(ActiveApplication)
    case noActiveApplication
}

@discardableResult
func toggleHotKeys(
    for application: ActiveApplication?
) -> ActiveApplicationToggleOutcome
```

Hotkey wrapper는 main actor에서 수행하는 첫 작업으로 대상 화면과 `activeApplicationProvider`의 fresh `ActiveApplication?`을 하나의 input snapshot으로 확정한다. 그 application snapshot을 canonical mutation method에 전달하고, 반환된 application을 HUD payload에도 사용한다. Mutation method는 다른 application을 독립적으로 다시 resolve하지 않는다. Snapshot이 `nil`이면 `.noActiveApplication`이며, non-`nil` snapshot은 enabled 또는 disabled 상태 중 하나로 반드시 toggle된다. Snapshot 이후 focus가 다른 앱으로 이동해도 최초 capture한 application의 상태와 HUD payload만 변경한다.

메뉴와 hotkey는 계속 같은 canonical mutation method를 사용한다. 메뉴는 fresh application을 resolve하는 convenience method를 호출하고 outcome을 무시한다. Mutation은 menu 상태 동기화를 위해 cached `activeApplication`을 전달된 snapshot으로 갱신할 수 있다.

## HUD 피드백 모델

HUD가 표시할 action은 세 가지로 제한한다.

```swift
enum ShortcutHUDAction {
    case appActivated
    case appHotKeysDisabled
    case appHotKeysEnabled
}
```

HUD payload에는 다음 정보가 포함된다.

- action
- 앱 이름
- bundle identifier
- 가능한 경우 application URL

`ShortcutHUDApplication`은 HUD에 필요한 앱 이름, bundle identifier, 가능한 application URL을 값으로 보관한다. Automatic Dock wrapper는 `DockItem`을 정확히 한 번 resolve하고 같은 item으로 이 값을 만든다. Finder는 canonical metadata `Finder`, `com.apple.finder`, URL 없음으로 같은 payload pipeline을 사용한다. Presenter는 Dock 목록, `DockItem`, Finder 상태를 다시 조회하지 않는다. 앱 icon resolve 순서는 application URL → bundle identifier → macOS 기본 application icon이다.

Automatic Dock의 non-empty 앱 이름은 application URL의 localized display name → `DockItem.name` → bundle identifier → URL filename 순으로 확정한다. Finder는 `Finder`를 사용하고, Active-app toggle은 `ActiveApplication.name` → bundle identifier 순으로 확정한다. Presenter는 앱 이름을 다시 resolve하지 않는다. 앱 이름은 화면 텍스트가 아니라 accessibility announcement에 사용한다.

Action과 accessibility 환경을 시각·의미 표현으로 바꾸는 로직은 pure `ShortcutHUDPresentation` mapping으로 분리한다. 이 값은 badge symbol, semantic badge role/color, announcement 문자열, scale animation 사용 여부, transparency fallback 여부를 표현하며 `Equatable`이어야 한다. 실제 `NSImage`, material, shadow rendering은 이 mapping 밖의 presenter/view가 담당한다.

### Module 배치

다음 HUD 관련 타입은 모두 `ZapApp` target에 둔다.

- `AppLaunchOutcome`
- `ActiveApplicationToggleOutcome`
- `ShortcutHUDAction`, payload, presentation mapping
- screen resolver와 scheduler
- presenter, panel, SwiftUI HUD view

`ZapCore`에는 HUD 전용 API를 추가하지 않는다. `ZapApp`은 기존 의존 방향으로 `ZapCore`의 `DisplayFrame`과 `ScreenDetector`를 재사용할 수 있다. `Package.swift`에 새 product 또는 package dependency를 추가하지 않으며, 신규 자동 테스트는 `Tests/ZapAppTests`에 둔다.

## Hotkey orchestration

HUD 정책은 Carbon dispatch나 공통 launcher 내부에 넣지 않는다.

Carbon `dispatchHotKey(id:)`의 성공은 알려진 ID를 callback에 전달했다는 의미일 뿐 실제 action 성공을 뜻하지 않는다. 또한 Automatic Dock과 Manual shortcut이 같은 launcher를 사용하므로 launcher 내부에서 HUD를 표시하면 Manual 경로에도 피드백이 노출된다.

`ZapAppModel`의 hotkey callback wiring에 입력별 wrapper를 두고 menu-facing 경로와 명시적으로 분리한다.

```swift
func resolveDockItem(for key: NumberKey) -> DockItem?

func activateDockItem(
    _ item: DockItem,
    completion: @escaping (AppLaunchOutcome) -> Void
)

func handleDockHotKey(_ key: NumberKey)
func activateDockItemFromMenu(for key: NumberKey)
func handleFinderHotKey()
func activateFinder()
```

```text
handleDockHotKey
  → 대상 화면 frame snapshot capture
  → Dock 목록 refresh
  → DockItem 정확히 한 번 resolve
  → 같은 item을 launcher에 전달
  → launcher outcome 확인
  → 성공 outcome과 같은 item metadata를 appActivated HUD로 변환

handleFinderHotKey
  → 대상 화면 frame snapshot capture
  → Finder launcher outcome 확인
  → 성공 outcome과 canonical Finder metadata를 appActivated HUD로 변환

Active-app toggle hotkey wrapper
  → 대상 화면 frame snapshot capture
  → fresh ActiveApplication 정확히 한 번 resolve
  → 같은 snapshot으로 canonical toggle method 호출
  → 반환된 application으로 disabled/enabled HUD 생성
```

`GlobalHotKeyService.onDockHotKey`는 `handleDockHotKey`, `onFinderHotKey`는 `handleFinderHotKey`에 연결한다. `activateDockItemFromMenu`와 menu-facing `activateFinder`는 같은 launcher를 호출할 수 있지만 outcome을 무시하고 HUD를 표시하지 않는다. Launcher completion에서 `DockItem`이나 Finder metadata를 다시 resolve하지 않는다.

모든 HUD 대상 hotkey 입력에는 `ZapAppModel`이 단조 증가하는 request generation을 부여한다. Automatic Dock, Finder, active-app toggle은 같은 generation을 공유한다. 비동기 launcher completion이 돌아왔을 때 capture한 generation이 최신 HUD hotkey 입력과 다르면 presenter와 accessibility announcement를 요청하지 않는다. 따라서 Dock과 Finder 입력의 completion이 역순으로 도착해도 최신 입력의 성공 결과만 표시한다. 최신 입력이 실패한 경우에도 이전 요청의 늦은 성공 completion은 표시하지 않는다. 이미 이전 completion과 HUD가 전달된 뒤 새 입력이 들어온 경우에는 서로 별개의 action으로 처리한다.

다음 경로는 HUD presenter를 호출하지 않는다.

- 메뉴의 Dock 앱 실행
- 메뉴의 Finder 실행
- 메뉴의 앱별 Enable/Disable
- Manual shortcut
- Window Management shortcut

## 화면 선택

HUD 대상 화면은 action 실행 직전에 immutable `DisplayFrame` snapshot으로 결정한다. 시스템 전역 keyboard focus가 sheet 또는 child panel에 있으면 그 owning top-level window가 속한 화면을 사용한다. 앱 전환이 끝난 뒤 화면을 다시 계산하지 않아 target app activation timing에 따라 HUD 위치가 바뀌지 않게 한다.

```swift
@MainActor
protocol ShortcutHUDScreenResolving {
    func resolveScreenBeforeAction() -> DisplayFrame?
}
```

Resolver algorithm은 다음과 같다.

1. 기존 `AccessibilityPermissionChecking.isTrusted`가 이미 `true`인 경우에만 `AccessibilityWindowControlling.frontmostWindow()`로 focused top-level window frame을 확인한다.
2. 기존 `ScreenDetector`와 `ScreenProviding` inventory로 window frame이 속한 display를 선택한다.
3. HUD resolution 과정에서는 Accessibility permission prompt를 절대 요청하지 않는다.
4. Permission이 없거나 AX/window/frame 조회가 실패하면 `NSEvent.mouseLocation`이 속한 display를 같은 inventory에서 선택한다.
5. 앞선 선택이 실패하면 같은 inventory의 primary display를 선택한다.
6. Screen inventory가 비어 있으면 `nil`을 반환한다. 원래 action은 계속 수행하고, 성공 시 presenter에 `display: nil`을 전달해 시각 HUD만 생략하고 announcement는 유지한다.

Automatic Dock HUD를 위해 새로운 Accessibility 권한을 요구하지 않는다. Resolver는 Window Management의 기존 screen inventory와 coordinate 처리 경계를 재사용하며, activation 이후 screen을 다시 조회하지 않는다.

## HUD presenter

HUD presenter는 action 처리와 독립된 protocol로 주입한다. 실제 구현은 AppKit panel과 SwiftUI content view를 조합한다.

```swift
@MainActor
protocol ShortcutHUDPresenting: AnyObject {
    func present(_ payload: ShortcutHUDPayload, on display: DisplayFrame?)
}
```

`display`가 `nil`이면 visual panel을 표시하지 않지만 accessibility announcement lifecycle은 그대로 수행한다.

Production panel contract:

- `styleMask: [.borderless, .nonactivatingPanel]`로 생성
- `canBecomeKey`와 `canBecomeMain`을 모두 `false`로 override한 전용 `NSPanel` subclass 사용
- `level = .floating`
- `collectionBehavior`에 `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.transient`, `.ignoresCycle` 포함
- 기존 presenter의 `.moveToActiveSpace` pattern을 사용하지 않음
- `ignoresMouseEvents = true`
- `hidesOnDeactivate = false`
- `isReleasedWhenClosed = false`
- presenter가 하나의 panel을 strong reference로 보유하고 `close` 대신 `orderOut`으로 숨김
- `NSApp.activate`, `makeKeyAndOrderFront`, `makeMain`을 호출하지 않고 `orderFrontRegardless()`처럼 non-activating ordering 사용
- `present`는 non-throwing이며 내부 표시 실패를 삼키고 원래 action 결과를 유지
- content 배경은 투명하고 SwiftUI HUD view가 material, corner radius, shadow를 렌더링

보이는 HUD card bounds는 132×132pt다. Panel frame은 외곽 shadow가 잘리지 않을 inset을 포함할 수 있으며 132×132pt로 제한하지 않는다. Card 중심을 선택된 display frame의 중심에 맞춘다.

Delayed lifecycle은 기존 pause scheduler pattern과 같은 주입 가능한 abstraction을 사용한다.

```swift
protocol ShortcutHUDScheduling: AnyObject {
    func schedule(after interval: TimeInterval, action: @escaping () -> Void)
    func cancel()
}
```

Presenter는 각 `present`마다 단조 증가하는 request generation을 발급하고 pending fade-out, hide, announcement 작업을 취소한다. 모든 delayed callback은 capture한 generation이 현재 generation과 일치할 때만 panel 또는 announcement state를 변경한다. 실제 시간 대기 대신 capturing scheduler로 테스트할 수 있어야 한다.

Presenter는 새 표시 요청을 받으면 icon과 badge를 갱신하고, card 중심을 정하고, accessibility 환경에 맞는 lifecycle을 시작한다. Visual phase는 `.hidden`, `.visible`, `.fadingOut`으로 유지하고 VoiceOver의 0.10초 debounce가 visual phase를 변경하지 않게 한다. Entry 중 새 요청은 현재 spring progress를 유지한 채 완료한다. 유지 구간의 새 요청은 opacity 1.0과 scale 1.0을 유지한다. Fade-out 중 새 요청은 fade-out을 취소하고 opacity와 scale을 즉시 1.0으로 복원한 뒤 새 요청 기준의 유지 및 fade-out 일정을 시작한다. 모든 경우 panel을 숨기거나 entry animation을 처음부터 재시작하지 않는다.

## 접근성

보이는 HUD는 텍스트를 포함하지 않지만, VoiceOver 사용자가 동일한 결과를 알 수 있어야 한다.

- 앱 활성화: `<App> activated`
- 앱별 Disable: `Zap shortcuts disabled in <App>`
- 앱별 Enable: `Zap shortcuts enabled in <App>`

현재 Zap의 사용자-facing 문자열과 accessibility 문자열이 English이므로 HUD announcement도 같은 언어와 용어를 사용한다. 이번 기능만을 위한 localization infrastructure는 추가하지 않는다. 향후 앱 전체 localization을 도입하면 이 문자열도 함께 이동한다.

Non-activating panel이 accessibility focus를 가져가지 않으므로 HUD와 독립된 announcement notification을 요청한다. Accessibility announcement는 각 HUD 요청 후 0.10초 debounce하여 발생한다. Debounce 중 새 요청이 들어오면 이전에 예약된 announcement를 취소하며, pending announcement가 실행되기 전에 들어온 연속 요청 묶음에서는 마지막 payload만 정확히 한 번 announce한다. 이미 announcement가 전달된 뒤 들어온 새 요청은 별도의 성공 action으로 announce할 수 있다. Announcement와 시각 HUD는 반드시 같은 payload와 request generation을 사용한다.

## 오류 및 fallback 처리

| 상황 | 처리 |
|---|---|
| Dock slot 없음 | hotkey wrapper가 beep 1회, HUD 없음 |
| 실행 중 앱 activation 실패 | launcher가 beep 1회, HUD 없음 |
| 새 앱 open 실패 | launcher가 beep 1회, HUD 없음 |
| Finder activation 또는 open 실패 | launcher가 beep 1회, HUD 없음 |
| 현재 앱 없음 | 상태 변경 없음, beep 없음, HUD 없음 |
| 앱 icon resolve 실패 | 기본 application icon으로 HUD 표시 |
| keyboard-focus top-level window 화면 없음 | 마우스 화면으로 fallback |
| 마우스 화면도 없음 | primary screen으로 fallback |
| screen inventory 비어 있음 | 원래 action 수행, 시각 HUD 없음, announcement는 계속 시도 |
| HUD panel 표시 실패 | 시각 피드백만 생략하고 accessibility announcement는 계속 시도 |
| accessibility announcement 실패 | 시각 HUD와 원래 action 결과는 유지 |

Panel 또는 announcement 실패가 앱 실행이나 앱별 상태 mutation을 실패시키거나 되돌리지 않게 한다. 시각 panel과 accessibility announcement는 서로 독립적으로 best-effort 처리한다.

## 향후 동작과의 경계

향후 같은 앱 단축키 반복 시 `Hide app` 또는 `Cycle Windows`가 추가되면 launcher outcome을 action별로 확장한다.

- activate 또는 launch: HUD 표시
- hide app: 필요 시 별도 승인된 HUD action으로 확장 가능
- cycle windows: HUD 표시 안 함

이번 설계에서 미래 action을 미리 구현하지 않는다. 다만 결과 기반 경계를 유지해 window cycle이 앱 활성화 HUD로 잘못 표현되지 않게 한다.

## 테스트 계획

### 실행 결과

1. 실행 중 앱 activation `true`가 `.activated`를 반환하고 beep를 내지 않는다.
2. 실행 중 앱 activation `false`가 beep를 정확히 한 번 낸 뒤 `.failed`를 반환한다.
3. 새 앱 open completion이 error 없이 running application을 반환하면 `.launched`를 반환하고 beep를 내지 않는다.
4. 새 앱 open completion의 error 또는 missing running application이 beep를 정확히 한 번 낸 뒤 `.failed`를 반환한다.
5. 실행 중 Finder activation 성공이 `.activated`를 반환하고 reopen event를 한 번 보낸다.
6. Finder activation 실패가 reopen event 없이 beep를 정확히 한 번 내고 `.failed`를 반환한다.
7. Finder open 성공은 `.launched`, URL 없음/error/missing running application은 beep 1회와 `.failed`를 반환한다.
8. Dock과 Finder completion이 main actor에서 정확히 한 번 전달된다.
9. `.failed`를 받은 hotkey와 menu caller가 추가 beep를 내지 않는다.
10. Manual shortcut과 Finder menu action이 outcome을 무시하고 HUD presenter를 호출하지 않는다.

### 앱별 toggle 결과

1. enabled 앱 snapshot을 toggle하면 `.disabled(app)`을 반환한다.
2. disabled 앱 snapshot을 toggle하면 `.enabled(app)`을 반환한다.
3. 현재 앱 snapshot이 없으면 beep 없이 `.noActiveApplication`을 반환한다.
4. Snapshot 이후 focused application이 바뀌어도 최초 snapshot의 상태만 변경하고 같은 app을 outcome에 반환한다.
5. 메뉴와 hotkey가 같은 snapshot-driven canonical mutation method를 사용한다.

### Hotkey 통합

1. Automatic Dock hotkey 성공 시 `.appActivated` payload를 presenter에 전달한다.
2. 없는 Dock slot은 beep를 정확히 한 번 내고 presenter를 호출하지 않는다.
3. activation/open 실패는 launcher beep 외에 추가 beep 없이 presenter를 호출하지 않는다.
4. 앱별 Disable hotkey가 최초 capture한 app의 `.appHotKeysDisabled` payload를 전달한다.
5. 앱별 Enable hotkey가 최초 capture한 app의 `.appHotKeysEnabled` payload를 전달한다.
6. `DockItem`을 한 번만 조회하고, 실행한 item의 application URL과 bundle identifier가 payload와 일치한다.
7. Automatic Dock 앱 이름은 localized URL name, `DockItem.name`, bundle identifier 순으로 fallback한다.
8. Active-app 이름은 `ActiveApplication.name`, bundle identifier 순으로 fallback한다.
9. Finder hotkey 성공은 입력 전 capture한 display에 canonical Finder payload를 전달한다.
10. Finder hotkey 실패는 model beep나 presenter 호출을 추가하지 않는다.
11. Dock과 Finder completion이 역순으로 도착해도 최신 HUD 대상 입력의 payload만 전달된다.
12. 최신 Finder 또는 Dock 입력이 실패하면 이전 요청의 늦은 성공 completion도 HUD를 표시하지 않는다.
13. Manual 및 Window Management callback은 presenter를 호출하지 않는다.
14. Dock/Finder/앱별 toggle menu action은 presenter를 호출하지 않는다.

### 화면 선택

1. Accessibility가 이미 trusted일 때 시스템 전역 keyboard focus가 있는 최상위 window의 화면을 우선한다.
2. Focus가 sheet 또는 child panel에 있으면 owning top-level window의 화면을 선택한다.
3. Permission이 없거나 AX/window/frame 조회가 실패하면 마우스 화면을 선택한다.
4. Resolver가 Accessibility permission prompt를 요청하지 않는다.
5. 앞선 화면을 모두 찾지 못하면 primary screen을 선택한다.
6. Screen inventory가 비어 있으면 `nil`을 반환하고 원래 action은 계속 수행한다.
7. Action 실행 전에 선택한 immutable `DisplayFrame`이 target app activation 이후에도 유지된다.

### Presentation mapping

1. `AppLaunchOutcome`, `ActiveApplicationToggleOutcome`, `ShortcutHUDAction`, application metadata, payload와 pure presentation mapping이 `Equatable`이다.
2. Dock metadata 이름 fallback과 canonical Finder metadata가 올바르다.
3. Action별 badge symbol과 semantic role/color가 badge 없음, 빨간 `−`, 초록 `✓`로 매핑된다.
4. Finder를 포함한 action별 English accessibility announcement가 올바르다.
5. Reduce Motion과 Reduce Transparency 네 조합이 scale animation 및 opaque background 정책에 독립적으로 매핑된다.
6. Glass outer border width와 inner highlight geometry가 승인된 card layout 값으로 유지된다.

### Presenter

1. Panel이 `.borderless`, `.nonactivatingPanel` style mask를 사용하고 key/main window가 되지 않는다.
2. Panel level이 `.floating`이고 collection behavior에 `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.transient`, `.ignoresCycle`이 포함된다.
3. Panel이 mouse event를 무시하고, deactivate 시 숨지 않으며, close 시 release되지 않는다.
4. Zap을 foreground로 활성화하거나 key/main window로 만들지 않는다.
5. 하나의 panel instance를 재사용하고 `orderOut`으로 숨긴다.
6. 보이는 card가 132×132pt이며 card 중심이 선택된 display frame 중앙에 맞고 shadow가 panel bounds에서 잘리지 않는다.
7. Icon은 application URL, bundle identifier, 기본 application icon 순으로 resolve한다.
8. Entry 중 새 요청은 현재 progress를 유지하고, fade-out 중 새 요청은 opacity와 scale을 1.0으로 복원한다.
9. 일반 모션은 fade 1.56초, hide 1.65초를 예약하고 Reduce Motion은 fade 1.30초, hide 1.39초를 예약한다.
10. Fade callback은 opacity만 변경하고 scale 1.0을 유지한다.
11. Request generation이 오래된 fade-out, hide, announcement callback의 state 변경을 막는다.
12. 빠른 A→B 요청은 0.10초 debounce 후 B만 정확히 한 번 announce하고 A는 announce하지 않는다.
13. Announcement callback은 visual phase를 변경하지 않는다.
14. Panel 표시가 실패해도 성공 action의 accessibility announcement를 시도한다.
15. `display == nil`이면 panel을 표시하지 않고 accessibility announcement만 시도한다.
16. Announcement 실패가 시각 HUD나 원래 action 결과를 변경하지 않는다.

Glass border, material, shadow, 실제 spring/fade의 시각 품질과 타사 전체 화면 앱 위 표시 여부는 수동 검증한다. 이번 기능을 위해 snapshot 또는 SwiftUI view-inspection dependency를 추가하지 않는다.

### 회귀 검증

```sh
swift test
make dev-build CODESIGN_IDENTITY=-
```

개발 앱에서 다음을 수동 검증한다.

1. Automatic Dock 단축키로 실행 중 앱과 종료된 앱을 각각 호출한다.
2. Finder global shortcut으로 실행 중 Finder를 활성화해 Finder icon HUD와 reopen 동작을 확인한다.
3. Keyboard focus를 가진 최상위 window가 서로 다른 여러 모니터에 있을 때 HUD 위치를 확인한다.
4. 현재 앱 토글 단축키로 Disable과 Enable badge를 확인한다.
5. Manual, Window Management, Dock/Finder/menu action에 HUD가 나타나지 않는지 확인한다.
6. HUD 표시 중 키보드 focus와 target app activation이 유지되는지 확인한다.
7. Finder와 Dock 단축키를 빠르게 연속 입력해 최신 HUD 교체와 dismiss timing을 확인한다.
8. 기본 모션이 빠르게 나타나 한 번만 작게 반동하고, 약 1.20초 선명하게 유지된 뒤 scale/blur 없이 빠르게 fade되는지 확인한다.
9. Reduce Motion과 Reduce Transparency 설정에서 fallback 표현을 확인한다.
10. 전체 화면 앱 위에서 HUD가 표시되는지 확인한다.
11. 실제 glass border, material, shadow, spring/fade 품질과 shadow clipping이 없는지 확인한다.
12. VoiceOver에서 English announcement가 보이는 HUD와 동일한 마지막 action을 설명하는지 확인한다.

## 구현 순서

1. `ShortcutHUDApplication` metadata와 Finder presentation mapping을 TDD로 추가한다.
2. Finder activation/launch를 `AppLaunchOutcome` completion과 exactly-once beep 계약으로 전환한다.
3. Finder hotkey 전용 wrapper, menu split, shared generation과 stale completion 통합 테스트를 작성한다.
4. C-style spring timing, opacity-only exit, Reduce Motion lifecycle을 presenter에 적용한다.
5. 고정 glass outer border와 inner highlight를 HUD view에 적용한다.
6. 전체 자동 테스트, 개발 빌드, Finder/Dock 실제 hotkey와 접근성 수동 검증을 수행한다.
