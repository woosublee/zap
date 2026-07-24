# Zap 현재 앱 토글 단축키 설계

## 배경

현재 Draft PR #8은 메뉴바에서 전역 단축키를 일정 시간 중지하거나, 현재 활성 앱에서만 Zap 단축키를 비활성화하는 기능을 제공한다. 앱별 비활성화는 현재 앱의 bundle identifier를 저장하고, 해당 앱이 활성화된 동안 Dock, Finder, Manual, Window Management 글로벌 단축키 등록을 해제한다. 다른 앱으로 전환하면 저장된 앱별 상태에 따라 단축키 등록을 복원한다.

현재 앱별 비활성화와 재활성화는 메뉴바의 `Disable Shortcuts in <App>` 또는 `Enable Shortcuts in <App>` 항목으로만 실행할 수 있다. 이번 변경은 같은 동작을 사용자 설정 가능한 글로벌 단축키 하나로 실행할 수 있게 한다.

## 목표

1. 현재 활성 앱에서 Zap 글로벌 단축키 사용을 중지하거나 재개하는 사용자 설정 단축키를 추가한다.
2. 같은 단축키를 한 번 누르면 현재 앱을 비활성화하고, 다시 누르면 재활성화한다.
3. 현재 앱이 비활성화된 동안에도 제어 단축키 자체는 등록 상태를 유지한다.
4. 기존 앱별 비활성화 목록과 persistence를 그대로 사용한다.
5. 기존 단축키 녹화 UI, keycap 표현, 충돌 오류 표시 방식을 재사용한다.

## 비목표

- 전역 `Pause Shortcuts` 기능의 동작 변경
- 전역 Pause를 키보드로 시작하거나 종료하는 기능
- 앱별 비활성화 목록을 조회하거나 편집하는 Settings UI
- 여러 개의 앱별 제어 단축키 지원
- 기본 단축키 조합 제공
- 새로운 sidebar 페이지 추가

## 사용자 동작

새 단축키의 초기 상태는 미설정이다. 사용자는 `Settings > General > Shortcut Controls`에서 단축키를 녹화한다.

단축키가 설정된 후의 동작은 다음과 같다.

1. 현재 앱에서 Zap 단축키가 활성화된 상태로 제어 단축키를 누른다.
2. 현재 앱의 bundle identifier가 앱별 비활성화 목록에 추가된다.
3. Dock, Finder, Manual, Window Management 단축키는 해제된다.
4. 제어 단축키는 계속 등록되어 있다.
5. 같은 단축키를 다시 누르면 현재 앱이 비활성화 목록에서 제거된다.
6. 일반 Zap 단축키 등록이 즉시 복원된다.

다른 앱으로 전환하면 기존 `NSWorkspace.didActivateApplicationNotification` 처리와 앱별 비활성화 목록에 따라 일반 단축키 등록 상태를 갱신한다.

전역 `Pause Shortcuts`가 활성화된 경우에는 기존 의미를 유지하기 위해 제어 단축키도 함께 해제한다. 이번 기능은 전역 Pause를 대체하거나 확장하지 않는다.

현재 앱의 bundle identifier를 확인할 수 없으면 입력을 무시하고 저장 상태를 변경하지 않는다.

## 설정 UI

`General` 화면에 `Shortcut Controls` 카드를 추가한다. 위치는 `Permissions` 다음, `Behavior` 이전으로 한다.

카드에는 한 개의 설정 행을 제공한다.

- 제목: `Toggle Zap for Current App`
- 설명: `Disable or re-enable Zap shortcuts for the currently active app.`
- trailing 영역: 현재 단축키를 표시하는 `ShortcutKeycapGroupView`
- 미설정 상태: 기존 keycap 컴포넌트의 unset 표현 사용
- keycap 클릭: `ShortcutRecorderView` 표시
- 설정된 단축키: 사용자가 제거할 수 있는 `Clear` 동작 제공

새로운 sidebar mode나 별도 페이지는 만들지 않는다. 이 기능은 Automatic, Manual, Window Management 전체에 영향을 주는 runtime control이므로 `General`에 배치한다.

## 단축키 모델과 persistence

제어 단축키는 단일 `Codable` 모델로 표현한다. 모델은 기존 Manual 및 Window shortcut 표현과 같은 정보를 가진다.

- optional key code
- optional key display name
- modifier set
- 등록 가능 여부

초기 기본값은 key와 modifier가 없는 미설정 상태다. 별도의 기본 키 조합을 제공하지 않는다.

설정은 전용 `UserDefaults` 키에 JSON으로 저장한다. 앱 시작 시 저장값을 복원하고, 녹화 또는 Clear 이후 즉시 저장한 뒤 글로벌 단축키 등록을 갱신한다. 잘못된 저장값은 미설정 기본값으로 복구한다.

별도의 enable toggle은 제공하지 않는다. 단축키 존재 여부가 활성 상태를 결정하며, Clear가 비활성화 동작을 담당한다.

## 글로벌 단축키 등록 구조

기존 `GlobalHotKeyRegistrationPlanner`와 `GlobalHotKeyService`를 확장한다. 제어 단축키를 Manual shortcut의 특수 항목이나 별도 서비스로 운영하지 않는다.

### Registration owner

새로운 registration owner를 추가한다.

```text
activeApplicationToggle
```

planner는 제어 단축키 조합을 Finder, Dock, Manual, Window보다 먼저 예약한다. 제어 단축키와 다른 Zap 단축키가 겹치면 제어 단축키가 우선하고, 후순위 단축키는 기존 conflict 처리에 따라 등록 계획에서 제외된다.

### 등록 상태

등록 계획은 runtime 상태에 따라 다음과 같이 적용한다.

| 상태 | 제어 단축키 | 일반 Zap 단축키 |
|---|---|---|
| 전역 Pause 활성 | 해제 | 해제 |
| 현재 앱이 앱별 비활성화 상태 | 등록 | 해제 |
| 일반 상태 | 등록 | 등록 |
| 제어 단축키 미설정 | 없음 | 기존 규칙대로 등록 |

현재 구현처럼 앱별 비활성화 상태에서 `unregister()`만 호출하면 제어 단축키까지 사라지므로, 제어 단축키만 포함하는 등록 계획과 전체 등록 계획을 구분할 수 있어야 한다.

### Dispatch

제어 단축키의 Carbon hotkey ID는 기존 Dock, Finder, Manual, Window 영역과 겹치지 않는 고정 영역을 사용한다. 해당 ID가 dispatch되면 `ZapAppModel.toggleHotKeysForActiveApplication()`을 호출한다.

메뉴바의 앱별 toggle도 같은 메서드를 계속 사용한다. 메뉴와 키보드 입력이 별도의 상태 변경 구현을 갖지 않도록 한다.

## 충돌 및 오류 처리

- 미설정 단축키는 등록하지 않으며 오류를 만들지 않는다.
- Zap 내부 단축키 충돌은 기존 planner conflict 오류 형식을 사용한다.
- macOS 또는 다른 앱이 조합을 점유한 경우 기존 `RegisterEventHotKey` 오류 분류를 사용한다.
- 제어 단축키 등록 실패는 기존 `registrationError`를 통해 Settings에 표시한다.
- 등록 실패 시에도 메뉴바의 앱별 Disable/Enable 동작은 계속 사용할 수 있다.
- 현재 앱을 확인할 수 없는 경우 앱별 상태와 persistence를 변경하지 않는다.

## 컴포넌트 변경

### `ZapAppModel`

- 제어 단축키 상태와 persistence를 소유한다.
- 녹화 결과 적용 및 Clear 메서드를 제공한다.
- 등록 갱신 시 전역 Pause, 현재 앱 비활성화, 일반 상태를 구분한다.
- 제어 단축키 dispatch를 기존 `toggleHotKeysForActiveApplication()`에 연결한다.

### `GlobalHotKeyRegistrationPlanner`

- 제어 단축키 입력과 owner를 추가한다.
- 제어 단축키를 가장 먼저 계획해 충돌 우선순위를 보장한다.
- 제어 전용 계획과 전체 계획을 만들 수 있도록 한다.

### `GlobalHotKeyService`

- 제어 단축키 Carbon ID를 등록하고 dispatch callback을 전달한다.
- 기존 unregister/register lifecycle과 오류 수집 방식을 유지한다.

### `ShortcutRecorderView`

- 현재 구조를 재사용한다.
- 제어 단축키에 맞는 title과 instruction context를 추가한다.
- modifier 없는 입력 거부, Escape 취소, key display 변환은 기존 동작을 유지한다.

### `SettingsView`

- `General`에 `Shortcut Controls` 카드를 추가한다.
- keycap, recorder presentation, Clear 동작을 연결한다.
- 신규 sidebar mode는 추가하지 않는다.

## 테스트 계획

### 모델 및 persistence

1. 초기 상태가 미설정인지 확인한다.
2. 녹화 결과가 저장되고 앱 재생성 시 복원되는지 확인한다.
3. Clear 이후 저장값과 등록 상태가 제거되는지 확인한다.
4. 손상된 저장값이 미설정 상태로 복구되는지 확인한다.

### Registration planner

1. 제어 단축키가 다른 owner보다 먼저 조합을 예약하는지 확인한다.
2. 제어 단축키와 Dock, Finder, Manual, Window 단축키 충돌 시 제어 단축키가 유지되는지 확인한다.
3. 미설정 제어 단축키가 계획에 포함되지 않는지 확인한다.
4. 제어 전용 계획이 일반 shortcut owner를 포함하지 않는지 확인한다.

### Dispatch와 통합 동작

1. 제어 단축키 ID가 앱별 toggle callback으로 dispatch되는지 확인한다.
2. 일반 상태에서 제어 단축키와 일반 단축키가 함께 등록되는지 확인한다.
3. 제어 단축키로 현재 앱을 비활성화한 뒤 제어 단축키만 남는지 확인한다.
4. 같은 키를 다시 눌러 현재 앱을 재활성화하고 일반 단축키를 복원하는지 확인한다.
5. 다른 앱으로 전환할 때 기존 앱별 exclusion 동작이 유지되는지 확인한다.
6. 전역 Pause 중에는 제어 단축키도 해제되는지 확인한다.
7. bundle identifier가 없는 앱에서는 상태를 변경하지 않는지 확인한다.

### Settings UI

1. General 화면에 `Shortcut Controls` 카드가 있는지 확인한다.
2. 카드가 `Toggle Zap for Current App` 행과 shortcut keycap을 렌더링하는지 확인한다.
3. keycap이 recorder를 열고 녹화 결과를 모델에 전달하는지 확인한다.
4. Clear가 설정을 미설정 상태로 되돌리는지 확인한다.

### 회귀 검증

```sh
swift test
make dev-build CODESIGN_IDENTITY=-
```

개발 앱에서 다음 흐름을 수동 검증한다.

1. 제어 단축키를 설정한다.
2. 임의의 앱에서 제어 단축키를 눌러 Zap 단축키가 중지되는지 확인한다.
3. 같은 제어 단축키가 중지 상태에서도 동작하는지 확인한다.
4. 다시 눌러 일반 Zap 단축키가 복원되는지 확인한다.
5. 앱 전환 후 저장된 앱별 상태가 유지되는지 확인한다.

## 구현 순서

1. 제어 단축키 모델과 persistence 테스트를 작성한다.
2. planner owner, 우선순위, 제어 전용 계획 테스트를 작성한다.
3. dispatch 및 앱별 disabled 상태 통합 테스트를 작성한다.
4. 모델, planner, service 등록 흐름을 구현한다.
5. recorder context와 General 설정 UI 테스트를 작성한다.
6. Settings UI를 구현한다.
7. 전체 테스트와 개발 앱 수동 검증을 수행한다.
