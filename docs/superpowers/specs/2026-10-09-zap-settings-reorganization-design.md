# Zap 설정 창 재구성 설계

작성일: 2026-10-09
대상: Zap macOS SwiftUI 앱
상태: 사용자 승인된 방향(목업 v2)을 구현 전 고정
선행 문서: `2026-06-10-zap-settings-general-and-window-rows-design.md`

## 목표

설정 창의 정보 구조를 목적별 3개 메뉴(General · Apps · Windows)로 줄이고, 화면 안의 중복·잘림·경고 반복을 정리한다. 단축키 등록, 저장, 권한 요청 등 모델 동작은 바꾸지 않는다. 향후 Mac App Store 빌드에서 Updates 영역을 숨길 수 있는 지점을 만들어 둔다.

## 비목표

- Mac App Store 출시 작업 자체(App Sandbox 적용, Sparkle 제거 빌드 구성, Dock plist 접근 검증, Apple Event reopen 대체)는 별도 작업으로 다룬다.
- 단축키 등록/충돌 처리 로직, `ZapAppModel`·`WindowManagementModel`의 저장 포맷 변경.
- 창 크기(820×640) 변경.

## 1. 사이드바

```
⚡ Zap
   Keyboard-first control

   General
   Apps
   Windows

   Version 1.0.0      ← 사이드바 하단
```

- `SettingsMode`는 `general`, `apps`, `windows` 세 가지로 줄인다. 순서도 이 순서다.
- 섹션 헤더(`SHORTCUTS`, `SYSTEM`)는 제거한다.
- 사이드바 하단에 `AboutPresentation.versionLine`(예: `Version 1.0.0 (42)`)을 caption 크기, secondary 색으로 표시한다.
- 아이콘: General `gearshape`, Apps `square.grid.2x2`, Windows `rectangle.3.group`.

## 2. 처음 여는 화면

- 마지막으로 선택한 화면을 `UserDefaults` 키 `settings_last_mode`에 `SettingsMode.rawValue`로 저장한다.
- 설정 창을 새로 만들 때 `initialMode` → 저장된 값 → `.general` 순서로 결정한다.
- 저장된 값이 알 수 없는 문자열이면 `.general`로 처리한다.
- `SettingsWindowPresenter.open(initialMode:)`의 기존 동작(창이 열려 있으면 해당 화면으로 전환)은 유지한다.

## 3. General 화면

카드 순서:

1. **Permissions**: Accessibility 행. 기존 동작 유지(권한 있음 `✓ Granted`, 없음 `Grant…` 버튼). 부제는 "Required for window shortcuts and per-app toggling."으로 바꾼다.
2. **Shortcut Controls**: "Toggle Zap for Current App" 행. 기존 keycap 녹화 버튼과 `Clear` 버튼을 유지한다. 이 카드 안에 있던 `registrationError` 표시는 제거한다(5절 배너로 이동).
3. **Behavior**: `Launch at login`, `Show menu bar icon`. `loginItemError`는 이 카드 안 inline으로 유지한다(로그인 항목 토글에만 해당하는 오류이기 때문).
4. **Updates**: `Automatically check for updates` 토글과 `Check Now` 버튼. Sparkle/EdDSA 설명 문구는 제거한다.
   - `AppDistribution.current.supportsInAppUpdates`가 `false`이면 카드 전체를 렌더링하지 않는다.

### AppDistribution

```swift
enum AppDistribution {
    case direct
    case appStore

    static var current: AppDistribution {
        #if ZAP_APP_STORE
        .appStore
        #else
        .direct
        #endif
    }

    var supportsInAppUpdates: Bool { self == .direct }
}
```

- 이번 작업에서 `ZAP_APP_STORE` 플래그를 정의하는 빌드 구성은 만들지 않는다. 판단 지점만 만든다.
- 메뉴바의 `Check for Updates...` 항목과 앱 메뉴의 `Check for Updates...` 명령도 같은 조건으로 숨긴다.

## 4. About

- 설정 창의 About 화면은 제거한다.
- 메뉴바 메뉴의 `Settings...` 위에 `About Zap` 항목을 추가하고, 이미 있는 `AboutWindowPresenter.open()`을 연결한다. 라벨은 `AboutPresentation.aboutMenuLabel(appName:)`을 사용한다.
- `AboutView`, `AboutWindowPresenter`는 그대로 재사용한다.

## 5. 오류 배너

- 새 컴포넌트 `SettingsIssueBanner(messages: [String])`: 메시지가 비어 있으면 아무것도 렌더링하지 않는다. 있으면 콘텐츠 영역 최상단(ScrollView 안, 첫 카드 위)에 주황색 배너로 각 메시지를 `exclamationmark.triangle.fill` 아이콘과 함께 한 줄씩 표시한다.
- 화면별로 들어가는 메시지:
  - 모든 화면: `model.registrationError`
  - Windows: 여기에 더해 `windowManagementModel.shortcutRegistrationError`, `windowManagementModel.windowManagementError`
- 같은 문자열은 한 번만 표시하고, `nil`이나 빈 문자열은 생략한다.
- Windows 화면의 배너는 `WindowManagementSettingsView`가 직접 렌더링한다. `SettingsView`는 `ZapAppModel`만 관찰하기 때문에 `windowManagementModel`의 `@Published` 오류 값이 바뀌어도 다시 그려지지 않는다. General과 Apps 화면의 배너는 `SettingsView`가 렌더링한다.
- 기존 각 카드 안의 `registrationError` 라벨들과 `WindowManagementSettingsView.shortcutErrorMessages`는 제거한다.
- 목업에 있던 "Show in list" 링크는 이번 범위에서 제외한다.

## 6. Apps 화면 (기존 Automatic + Manual)

### Dock Apps 카드

- 제목 `Dock Apps`, 부제 "Your first nine pinned Dock apps, in order.", 제목 줄 오른쪽에 `Refresh` 버튼(기존 `model.refreshDockItems()`).
- 기존 "Refresh the Dock when pinned apps change." 안내 줄은 제거한다.
- 첫 행: 라벨 `Modifier`, 오른쪽에 기존 `ModifierKeyButton` 4개 + `+ 1–9` 텍스트.
- 그 아래 2열 그리드는 기존과 같다. 첫 칸 Finder 행 오른쪽 끝에 `isFinderShortcutEnabled` 스위치를 붙인다. 꺼지면 지금처럼 행을 흐리게 표시한다.
- 기존 상단 `Shortcuts` 카드(`automaticShortcutsSection`)는 제거한다.

### Custom Apps 카드 (기존 Manual)

- 제목 `Custom Apps`, 부제 "Any app, any shortcut.", 제목 줄 오른쪽에 `Add App…` 버튼(기존 `addManualShortcut()`).
- 행 구성(`ManualShortcutRow`)은 그대로 둔다.
- 비어 있을 때 문구는 "No custom apps yet"으로 바꾼다.
- `addManualShortcut()`의 `selectedMode = .manual`은 `.apps`로 바꾼다.

## 7. Windows 화면

- 카드 제목을 `Shortcuts`에서 `Window Shortcuts`로 바꾸고 부제는 제거한다.
- 제목 줄 오른쪽에 전역 enable 스위치와 `Reset to Defaults` 버튼을 나란히 둔다. 스위치는 라벨을 숨기고, 접근성 라벨은 "Enable window management shortcuts"로 유지한다.
- 이를 위해 `SettingsCard`에 제목 줄 오른쪽 `accessory` 슬롯을 추가한다. Apps 화면의 `Refresh`, `Add App…` 버튼도 이 슬롯을 쓴다.
- 권한 잠금 안내 문구는 "Grant \(AccessibilityPaneName.current) in General to use window shortcuts."로 바꾸고 위치는 유지한다.
- 카테고리 그룹은 2열 `LazyVGrid`를 버리고 **단일 열 목록**으로 바꾼다. 행 사이는 구분선으로 나누고 행 배경 박스는 제거한다.
- 카테고리 제목은 caption 크기, 대문자, secondary 색으로 표시한다.
- `WindowShortcutRowView`는 바꾸지 않는다. keycap을 클릭하면 녹화하고, 체크 아이콘 버튼으로 활성/비활성을 바꾸고, 권한이 없으면 잠긴다. 목업에서 스위치로 그린 부분은 기존 체크 아이콘 버튼을 그대로 쓴다. 이름 텍스트는 `lineLimit(1)`을 유지하되 단일 열이라 잘리지 않아야 한다.

## 8. Keycap 표시

- `ShortcutKeycapView`가 라벨을 그릴 때 여러 글자로 된 키 이름을 기호로 바꾼다: `Return`→`↩`, `Tab`→`⇥`, `Delete`→`⌫`, `Esc`→`⎋`. `Space`는 단어를 그대로 쓴다.
- 이 변환은 표시 계층에서만 한다. `ShortcutKeyDisplay`와 저장되는 `keyDisplayName`은 바꾸지 않는다. 접근성 라벨도 원래 문자열을 유지한다.
- keycap 라벨 `Text`에 `lineLimit(1)`과 `fixedSize()`를 적용해 줄바꿈("Ret / urn")을 막는다.

## 컴포넌트와 파일 영향

- `Sources/ZapApp/Views/SettingsView.swift`: `SettingsMode` 축소, 사이드바, General/Apps 화면 재구성, 배너 연결, 마지막 화면 저장.
- `Sources/ZapApp/Views/WindowManagementSettingsView.swift`: 카드 제목, 단일 열 목록, 오류 표시 제거.
- `Sources/ZapApp/Views/ZapDesignSystem.swift`: `SettingsIssueBanner`, keycap 기호 변환과 줄바꿈 방지.
- `Sources/ZapApp/Services/SettingsWindowPresenter.swift`: 초기 화면 결정 로직.
- `Sources/ZapApp/Models/AppDistribution.swift` (새 파일).
- `Sources/ZapApp/Views/MenuBarView.swift`, `Sources/ZapApp/ZapApp.swift`: `About Zap` 항목 추가, 업데이트 항목 조건부 표시.
- 테스트: `SettingsWindowManagementUITests`, `SettingsShortcutControlsUITests`의 모드 목록과 소스 문자열 단언을 갱신한다. 새 테스트는 초기 화면 결정(저장값 없음 / 알 수 없는 값 / initialMode 우선), keycap 기호 변환, 배너 메시지 중복 제거, `AppDistribution.direct.supportsInAppUpdates == true`를 다룬다.

## 검증

- `swift test` 전체 통과.
- 앱을 실행해 세 화면을 직접 확인한다.
- README가 참조하는 스크린샷 2장을 새 구성으로 교체한다: `settings-automatic.png` → `settings-apps.png`, `settings-window-management.png` → `settings-windows.png`. README의 경로와 alt 텍스트도 갱신한다. 어디서도 참조하지 않는 `settings-manual.png`는 삭제한다.
