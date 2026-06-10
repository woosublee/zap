# Zap 네이티브 메뉴바 설계

## 배경

PR #6의 현재 메뉴바는 `MenuBarExtra`에 `.menuBarExtraStyle(.window)`를 적용하고, `MenuBarView`가 커스텀 `VStack` 기반 패널을 렌더링한다. 이 구조는 브랜드 헤더, 상태 섹션, 키캡 스타일을 보여주기 좋지만 Quick Launch 항목이 많아지면 메뉴가 아래로 길게 늘어진다. 또한 Window Management는 실제 액션 목록이 아니라 설정 진입 항목만 제공한다.

이번 변경의 목표는 메뉴바를 macOS 기본 메뉴 UX에 맞춰 짧고 계층적인 구조로 정리하는 것이다.

## 목표

1. 메뉴바에서 권한 상태 표시를 제거한다.
   - `Accessibility Ready / Needs Permission`
   - shortcut registration error
   - window management error
2. Quick Launch 항목을 `Quick Launch` 서브메뉴 아래로 이동한다.
3. Window Control 항목을 `Window Control` 서브메뉴 아래에 실제 실행 액션으로 제공한다.
4. 메뉴바의 About 항목을 제거하고 Settings 내부 메뉴로 이동한다.
5. 기존 launch, shortcut, window action 동작은 유지한다.

## 비목표

- 새 윈도우 관리 액션 추가
- global hotkey 등록 방식 변경
- 권한 요청 UX 재설계
- Sparkle 업데이트 UX 변경
- 기존 About window presenter 삭제

## 메뉴바 구조

`ZapApp`의 `MenuBarExtra`는 `.menuBarExtraStyle(.menu)`로 전환한다. `MenuBarView`는 더 이상 커스텀 패널을 렌더링하지 않고 SwiftUI 기본 `Menu`, `Button`, `Divider`로 메뉴 컨텐츠를 구성한다.

예상 구조:

```text
Zap dev
────────────────
Quick Launch
  Finder                 ⌥`
  <Manual shortcuts...>
  <Dock apps 1–9...>

Window Control
  Center                 <shortcut>
  Fullscreen             <shortcut>
  Left Half              <shortcut>
  Right Half             <shortcut>
  Top Half               <shortcut>
  Bottom Half            <shortcut>
  Upper Left             <shortcut>
  Upper Right            <shortcut>
  Lower Left             <shortcut>
  Lower Right            <shortcut>
  ─────────────
  Next Display           <shortcut>
  Previous Display       <shortcut>
  ─────────────
  Next Third             <shortcut>
  Previous Third         <shortcut>
  Larger                 <shortcut>
  Smaller                <shortcut>
  ─────────────
  Undo                   <shortcut>
  Redo                   <shortcut>
────────────────
Refresh Dock Apps
Check for Updates...
Settings...
Quit Zap dev
```

`Window Control` 내부는 별도 nested category menu를 만들지 않고 category 사이에 `Divider`를 둔다. 이유는 `Window Control` 자체가 이미 서브메뉴이므로, 그 안에서 다시 `Positioning`, `Display`, `Sizing`, `History` 서브메뉴를 만들면 자주 쓰는 윈도우 액션 접근이 한 단계 더 깊어지기 때문이다.

## 컴포넌트 변경

### `MenuBarView`

입력 의존성은 단순화한다.

- 유지:
  - `model`
  - `updateService`
  - `openSettings`
  - `quit`
- 제거:
  - `openWindowManagementSettings`
  - `openAbout`
  - 커스텀 `StatusRow`
  - 커스텀 `MenuRow`
  - 커스텀 header/separator/section label UI

`MenuBarView`는 다음 하위 빌더를 가진다.

- `quickLaunchMenu`
- `windowControlMenu`
- `maintenanceActions`
- `appActions`

### Quick Launch

Quick Launch는 기존 동작을 그대로 사용한다.

- Finder가 활성화되어 있으면 `Finder` 항목을 보여주고 `model.activateFinder()`를 호출한다.
- `model.activeManualShortcuts`를 메뉴 항목으로 보여주고 `model.activateManualShortcut(id:)`를 호출한다.
- `NumberKey.allCases`를 순회하되 `model.dockItem(for:)`가 있는 Dock app만 표시한다.
- 빈 Dock slot은 표시하지 않는다.

Shortcut 표시는 네이티브 메뉴 shortcut 등록이 아니라 label 문자열에 붙이는 방식으로 처리한다. 이미 global hotkey는 `GlobalHotKeyService`에서 등록하므로 메뉴 shortcut으로 중복 등록하지 않는다.

### Window Control

Window Control은 `model.windowManagementModel.windowShortcuts`를 사용한다. 이 배열은 기본 shortcut과 사용자 변경 shortcut을 모두 반영한다.

- 각 `WindowShortcut`의 `action.displayName`을 메뉴 label로 사용한다.
- `WindowShortcutDisplay.shortcutTitle(for:)`가 있으면 label 뒤에 shortcut 문자열을 붙인다.
- 항목 클릭 시 `model.windowManagementModel.perform(action:)`를 호출한다.
- category 순서는 `WindowActionCategory.allCases` 순서를 따른다.
- category 사이에는 `Divider`를 넣는다.

Window management가 비활성화되어 있거나 Accessibility 권한이 없는 경우에도 메뉴 항목은 표시한다. 실행 결과는 기존 `WindowManagementModel.perform(action:)` 경로에서 처리하고, 실패하면 `windowManagementError`에 기록한다. 메뉴바 자체에는 상태나 오류를 표시하지 않는다.

## About 이동

메뉴바 드롭다운에서는 About 항목과 `openAbout` 의존성을 제거한다.

Settings sidebar에는 `.about` 모드를 추가한다.

```text
Shortcuts
  Automatic
  Manual
  Window Management

System
  Setting
  About
```

`SettingsView`의 `.about` 화면은 기존 `AboutView`와 `AboutPresentation`을 재사용한다. `AboutView`는 floating window 안에서도 쓸 수 있도록 그대로 유지하고, Settings 패널에서는 추가 `SettingsCard` wrapper 없이 직접 배치한다.

기존 `AboutWindowPresenter`는 삭제하지 않는다. 향후 macOS app menu나 테스트에서 재사용 가능하고, 이번 변경의 목표는 메뉴바에서 About을 제거하는 것이지 presenter를 폐기하는 것이 아니기 때문이다.

## 에러 처리

메뉴바는 상태와 오류를 보여주지 않는다.

대신 기존 Settings 내부 표시를 유지한다.

- Accessibility 권한 부족: `Settings > Setting > Permissions`
- Window Management 권한 안내: `Window Management` 화면의 lock 안내
- Shortcut registration error: 관련 Settings 화면의 error label
- Window management error: `WindowManagementModel.windowManagementError`를 기존 Settings 화면에서 표시

이 방식은 메뉴바를 실행 메뉴로 단순화하고, 설정/진단 정보는 Settings로 모으는 구조다.

## 테스트 계획

기존 `MenuBarViewTests`는 커스텀 패널 구조를 전제로 하므로 네이티브 메뉴 구조 기준으로 수정한다.

테스트에서 확인할 내용:

1. `MenuBarView`에 `Menu("Quick Launch")`가 존재한다.
2. `MenuBarView`에 `Menu("Window Control")`가 존재한다.
3. `MenuBarView`가 `Status`, `Accessibility`, `Ready`, `Needs Permission`을 더 이상 포함하지 않는다.
4. `MenuBarView`가 `activeManualShortcuts`, `NumberKey.allCases`, `windowManagementModel.windowShortcuts`를 사용한다.
5. `MenuBarView`가 `About` 메뉴 항목과 `openAbout` 의존성을 더 이상 갖지 않는다.
6. `SettingsMode`에 `.about`이 추가된다.
7. Settings sidebar가 `.about`을 `System` 섹션에 노출한다.
8. `.about` 선택 시 추가 `SettingsCard` wrapper 없이 `AboutView`를 렌더링한다.
9. Settings 오른쪽 콘텐츠 영역은 모드별 상단 title/subtitle header를 렌더링하지 않는다.

검증 명령:

```sh
swift test
make dev-run
osascript -e 'application id "com.woosublee.zap.dev" is running'
```

## 범위와 순서

1. 메뉴 관련 테스트를 새 기대 구조로 갱신한다.
2. `MenuBarView`를 네이티브 메뉴 빌더 구조로 변경한다.
3. `ZapApp`에서 `.menuBarExtraStyle(.menu)`로 전환하고 제거된 의존성을 정리한다.
4. `SettingsMode`와 `SettingsView`에 About 모드를 추가한다.
5. `swift test`로 회귀를 확인한다.
6. 개발 빌드로 실행해 메뉴바 앱이 뜨는지 확인한다.
