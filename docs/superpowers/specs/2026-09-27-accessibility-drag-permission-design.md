# Zap 손쉬운 사용 권한 드래그 안내 설계

## 배경

Zap이 필요로 하는 시스템 권한은 손쉬운 사용(Accessibility) 하나다. 현재 권한 요청 흐름은 다음과 같다.

- Settings > General > Permissions의 `Request` 버튼이 `AXIsProcessTrustedWithOptions` 시스템 프롬프트를 띄운다.
- 사용자는 시스템 설정에서 목록을 직접 찾아 Zap 토글을 켜야 한다.
- 권한 없이 창 관리 단축키를 누르면 `WindowManagementService`가 `.accessibilityPermissionMissing`으로 실패하고, 실패 비프 외에는 아무 안내가 없다.

최근 macOS 앱들(CleanShot, Codex, Claude 데스크톱 등)은 시스템 설정의 해당 개인정보 보호 패널을 열고, 설정 창 옆에 앱 아이콘이 담긴 떠 있는 패널을 붙여 사용자가 아이콘을 목록으로 끌어다 놓게 한다. Zap도 같은 방식으로 "어디서 무엇을 켜야 하는지" 헤매지 않게 만든다.

또한 macOS 27부터 시스템 설정의 손쉬운 사용 페이지 이름이 "Device Control and Data Access"로 바뀌었다(URL과 `Privacy_Accessibility` anchor는 동일). Zap의 안내 문구도 OS 버전에 맞는 이름을 보여야 한다.

## 목표

1. `Grant…` 버튼을 누르면 시스템 설정의 손쉬운 사용 패널을 열고, 설정 창을 따라다니는 Zap 아이콘 드래그 패널을 표시한다.
2. 권한 없이 창 관리 단축키를 누르면 앱 세션당 한 번 같은 드래그 안내를 시작한다.
3. 기존 `AXIsProcessTrustedWithOptions` 프롬프트는 더 이상 띄우지 않는다.
4. 권한 페이지 이름은 OS 버전에 맞게 표시한다(macOS 27+: Device Control and Data Access, 이전: Accessibility).
5. 드래그 패널 구현은 교체 가능한 경계 뒤에 둔다.

## 비목표

- 첫 실행 온보딩 화면
- 손쉬운 사용 외 다른 권한(화면 기록, 입력 모니터링 등)
- 드래그 패널의 Zap 디자인 시스템 커스터마이즈
- 오래된(stale) 권한 항목 정리 또는 재서명 후 권한 복구 안내
- 설정 토글 이후 AX 반영 지연 처리

## 접근 방식

오픈소스 [jaywcjlove/PermissionFlow](https://github.com/jaywcjlove/PermissionFlow)(MIT, 외부 의존성 없음, macOS 13+)를 도입한다. 이 라이브러리는 다음을 제공한다.

- 대상 개인정보 보호 패널 열기
- 클릭 위치에서 시스템 설정 창으로 날아가는 패널 애니메이션
- 시스템 설정 창 이동 추적, 창 종료 시 패널 자동 닫기
- 현재 `.app`을 네이티브 drag source로 표시
- 한 번에 패널 하나만 유지
- `PermissionFlowResources`를 통한 크래시 없는 리소스 번들 조회와 OS 버전별 손쉬운 사용 페이지 이름

직접 구현(`NSPanel` + `NSDraggingSource` + `CGWindowListCopyWindowInfo` 기반 창 추적)은 대안으로 남긴다. 리소스 번들 패키징이나 동작에 해결할 수 없는 문제가 생기면 `AccessibilityPermissionGuide` 구현만 교체한다.

## 구성 요소

### `AccessibilityPermissionGuiding` / `AccessibilityPermissionGuide` (Services, 신규)

```swift
@MainActor
protocol AccessibilityPermissionGuiding {
    func start(sourceFrame: CGRect?)
}
```

- `PermissionFlow`를 import하는 유일한 파일이다.
- `PermissionFlow.makeController(configuration:)`로 컨트롤러를 한 번 만들어 보관한다.
  - `requiredAppURLs: [Bundle.main.bundleURL]`
  - `promptForAccessibilityTrust: false`
- `start(sourceFrame:)`
  - `AccessibilityPermissionChecking.isTrusted`가 true면 아무것도 하지 않는다.
  - 아니면 `authorize(pane: .accessibility, suggestedAppURLs: [Bundle.main.bundleURL], sourceFrameInScreen: sourceFrame)`를 호출한다.
- 권한 페이지 표시 이름은 `PermissionFlowResources.accessibilityNameResource`를 노출하는 작은 정적 helper로 제공한다.

### `PermissionGuideThrottle` (신규)

- 창 단축키 경로에서 가이드를 앱 세션당 한 번만 띄우기 위한 순수 로직이다.
- `mutating func shouldStart() -> Bool`: 첫 호출은 true, 이후는 false를 반환한다.
- 메모리에만 상태를 두며 앱을 재실행하면 초기화된다.

### `WindowManagementModel` (변경)

- init에 `permissionGuide: AccessibilityPermissionGuiding`을 주입받는다. 기본값은 `AccessibilityPermissionGuide()`다.
- `requestAccessibilityPermission(sourceFrame: CGRect? = nil)`는 `permissionService.requestPrompt()` 대신 `permissionGuide.start(sourceFrame:)`를 호출한다.
- `perform(action:)`가 `.failure(.accessibilityPermissionMissing)`를 받고 throttle이 통과하면 `permissionGuide.start(sourceFrame: nil)`을 호출한다.
- `WindowManagementService`는 변경하지 않는다.

### `SettingsView` Permissions 섹션 (변경)

- 행 제목은 OS 버전에 맞는 권한 페이지 이름(`accessibilityNameResource`)을 사용한다.
- 부제는 `Drag Zap into the list to let it move and resize windows.`로 바꾼다.
- 버튼 이름을 `Request`에서 `Grant…`로 바꾼다.
- 버튼의 화면 좌표 frame을 구해 `requestAccessibilityPermission(sourceFrame:)`에 전달한다. frame을 구하지 못하면 nil로 호출한다.
- 기존 `onAppear` / `didBecomeActive` 권한 재확인은 유지한다.

### `AccessibilityPermissionService` (유지)

- `isTrusted`는 그대로 사용한다.
- `requestPrompt()`는 호출처가 없어지면 프로토콜과 구현에서 제거한다.

## 흐름

```
[Grant… 클릭] 또는 [권한 없이 창 단축키 (세션 첫 1회)]
  → WindowManagementModel → AccessibilityPermissionGuide.start(sourceFrame:)
  → 이미 권한 있음? → 종료
  → PermissionFlow: 시스템 설정 > 손쉬운 사용 열기
  → Zap 아이콘 패널이 설정 창 옆에 붙음 (창 이동을 따라감)
  → 사용자가 아이콘을 목록으로 드래그 → 토글 켬
  → 설정 창을 닫으면 패널 닫힘
  → Zap 재활성화 시 didBecomeActive 재확인 → "Granted"
```

## 패키징과 서명

- `Package.swift`
  - `.package(url: "https://github.com/jaywcjlove/PermissionFlow", exact: "2.11.2")`를 추가한다.
  - `ZapApp` target에는 `.product(name: "PermissionFlow", package: "PermissionFlow")`만 연결한다. 선택형 status 모듈은 연결하지 않는다.
  - PermissionFlow의 manifest는 `swift-tools-version 6.2`를 요구한다. 로컬 툴체인은 Swift 6.4이므로 빌드할 수 있다. Zap 루트 manifest의 tools-version은 바꾸지 않는다.
- `Makefile` `bundle` 단계
  - `swift build --show-bin-path` 아래의 `PermissionFlow_PermissionFlow.bundle`을 `Contents/Resources/`로 `ditto --norsrc --noextattr`한다.
  - 번들을 찾지 못하면 빌드를 실패시킨다.
- 서명: 번들에는 실행 코드가 없고 `.lproj` 리소스만 있으므로, 기존의 앱 전체 `codesign`에 함께 봉인된다. 별도로 서명하지 않는다.
- `Makefile` `verify` 단계: `test -d "$(RESOURCES_DIR)/PermissionFlow_PermissionFlow.bundle"`를 추가한다.
- 구현 초기에 번들된 앱에서 `PermissionFlowResources.packageBundle`이 nil이 아닌지 확인한다. nil이면 라이브러리가 탐색하는 위치로 복사 경로를 조정한다. 번들을 찾지 못해도 라이브러리는 크래시 없이 영어 기본 문구로 대체한다.

## 예외 상황

| 상황 | 동작 |
|---|---|
| 이미 권한이 있는 상태에서 호출 | `start`가 no-op |
| 패널이 떠 있는 상태에서 다시 호출 | 라이브러리가 단일 패널을 유지 |
| 권한 없이 단축키 반복 입력 | 세션 첫 1회만 가이드, 이후는 기존 실패 비프만 |
| 사용자가 드래그 없이 설정 창을 닫음 | 패널 자동 닫힘, `Grant…`로 다시 시작 가능 |
| 권한 획득 후 | 기존 `didBecomeActive` 재확인으로 "Granted" 표시 |
| 리소스 번들 누락 | 크래시 없이 영어 기본 문구 사용 |

## 테스트

### 단위 테스트

- `PermissionGuideThrottleTests`: 첫 `shouldStart()`는 true, 두 번째부터는 false인지 확인한다.
- `WindowManagementModelTests` (가짜 `AccessibilityPermissionGuiding` 주입)
  - `requestAccessibilityPermission(sourceFrame:)`가 guide `start`를 전달받은 frame으로 한 번 호출하는지 확인한다.
  - 권한 없이 `perform(action:)`를 두 번 호출하면 guide `start`가 `sourceFrame: nil`로 한 번만 호출되는지 확인한다.
  - `perform(action:)`의 다른 실패(예: `.focusedWindowMissing`)에서는 guide를 호출하지 않는지 확인한다.
  - 기존 `testPermissionButtonsRequestPromptRefreshStateAndOpenSettings`를 새 동작에 맞게 수정한다.
- Makefile을 검사하는 기존 테스트 패턴(`ReleaseWorkflowTests` 등)이 있으면 번들 복사와 verify 항목을 확인하는 테스트를 추가한다.

### 수동 검증

1. `make dev-run`으로 실행하고, 시스템 설정의 손쉬운 사용 목록에서 Zap을 제거한다.
2. Settings > General > `Grant…`를 누르면 패널이 버튼에서 설정 창으로 날아가 붙는지, 드래그가 되는지, 토글을 켠 뒤 "Granted"로 바뀌는지 확인한다.
3. 권한을 다시 제거한 뒤 창 관리 단축키를 누르면 가이드가 한 번 뜨고, 반복해 눌러도 다시 뜨지 않는지 확인한다.
4. macOS 27에서 행 제목이 "Device Control and Data Access"(한국어 환경에서는 해당 번역)로 표시되는지 확인한다.
5. `make verify`에서 `codesign --verify --strict`가 통과하는지 확인한다.
