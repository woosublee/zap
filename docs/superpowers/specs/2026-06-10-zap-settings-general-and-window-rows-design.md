# Zap 설정 UI 후속 리디자인 설계

작성일: 2026-06-10
대상: Zap macOS SwiftUI 앱
상태: 사용자 승인된 방향을 구현 전 고정

## 목표

현재 리디자인된 설정 UI에서 사용자가 피드백한 정보 구조와 행 동작을 반영한다. 기능 자체는 바꾸지 않고, 동일한 모델 API와 저장/등록 동작을 유지한 채 표현 계층만 조정한다.

## 확정된 변경사항

### 1. 사이드바 정보 구조

사이드바는 현재 리디자인의 좌측 사이드바 방향을 유지한다. 다만 시스템성 항목을 여러 메뉴로 쪼개지 않고 `General` 하나로 묶는다.

- `Shortcuts`
  - `Automatic`
  - `Manual`
  - `Window Management`
- `System`
  - `General`

`Accessibility`, `Behavior`, `Updates`는 각각 독립 사이드바 메뉴로 만들지 않는다.

### 2. General 화면

`General` 화면은 앱 설정성 항목을 한곳에서 관리한다.

- `Permissions` 카드
  - `Accessibility` 권한 행 하나를 표시한다.
  - 권한 있음: 초록 체크 아이콘과 `Granted` 상태를 표시한다.
  - 권한 없음: 상태 텍스트(`Required`) 없이 `Request` 버튼만 표시한다.
  - 기존 `Open Accessibility Settings`, `Refresh Permission`, `Request Permission` 3버튼 구조는 제거한다.
- `Behavior` 카드
  - `Launch at login`
  - `Show menu bar icon`
- `Updates` 카드
  - `Automatically check for updates`
  - `Check Now` 버튼
  - Sparkle/EdDSA 설명 문구

### 3. Automatic 화면의 Finder 표시

Finder shortcut은 상단 `Shortcuts` 카드에서 기존처럼 토글로 활성화 여부를 표시한다.

하단 `Automatic Dock Apps` 목록에서는 Finder를 활성화 여부와 무관하게 항상 표시한다. 비활성화된 경우 행과 keycap을 흐리게 처리해 “존재하지만 꺼져 있음”을 보여준다.

### 4. Window Management 화면

`Window Management` 화면은 단축키 중심으로만 구성한다.

- Accessibility 권한 섹션은 제거하고 `General > Permissions`로 이동한다.
- 별도 `Status` 카드는 삭제한다.
- 전역 등록 오류나 윈도우 관리 오류를 완전히 숨기지는 않고, 관련 단축키 섹션 아래 inline 경고로만 표시한다.
- 권한이 없을 때도 “Enable window management shortcuts” 전역 토글은 조작 가능해야 한다.
- 권한이 없을 때 개별 단축키 편집/녹화는 잠긴 상태로 표현한다.

### 5. Window shortcut row 동작

각 윈도우 단축키 행에서 버튼 수를 줄인다.

- `Record` 버튼 삭제
- `Disable` 버튼 삭제
- 체크박스 삭제
- keycap 그룹 클릭 시 녹화 시트를 연다.
- 오른쪽 토글은 해당 단축키 활성/비활성만 제어한다.
- shortcut이 미설정이면 keycap 영역은 `Not set` 형태로 표시하고, 클릭 시 녹화 시트를 연다.
- 권한 잠금 상태에서는 keycap 클릭과 토글을 비활성화한다.

### 6. Positioning 카테고리 배치

Window Management의 `Positioning` 카테고리는 가능하면 2열로 표시한다.

- Positioning: 2열 그리드
- Display / Sizing / History: 기존과 유사한 단일 열 그룹

## 컴포넌트와 파일 영향

- `Sources/ZapApp/Views/SettingsView.swift`
  - `SettingsMode`에 `general` 추가
  - 사이드바를 `Shortcuts` / `System` 그룹으로 표시
  - `Behavior`, `Updates`를 기존 모든 모드 하단 공통 섹션에서 제거하고 General 화면으로 이동
  - Automatic Dock Apps에서 Finder 행을 항상 표시
- `Sources/ZapApp/Views/WindowManagementSettingsView.swift`
  - Accessibility Permission 카드 제거
  - Status 카드 제거
  - inline 오류 표시 유지
  - Positioning 카테고리만 2열 레이아웃 적용
- `Sources/ZapApp/Views/WindowShortcutRowView.swift`
  - Record/Disable 버튼 제거
  - keycap 영역 클릭 녹화
  - 우측 토글 방식으로 활성/비활성 제어
- `Sources/ZapApp/Views/ZapDesignSystem.swift`
  - Permission row나 clickable keycap 스타일이 필요하면 기존 keycap/card 토큰을 재사용한다.
- 관련 테스트
  - 사이드바 General 구조
  - Finder 하단 목록 항상 표시 및 비활성 흐림 처리
  - Window row 버튼 제거와 keycap 녹화 진입
  - Positioning 2열
  - Status 카드 삭제
  - 권한 상태 General Permissions 카드 표시

## 비범위

- 권한 요청/확인 API의 실제 동작 변경 없음
- 단축키 등록/저장 모델 변경 없음
- 새 권한 종류 추가 없음
- 메뉴바 드롭다운 디자인 추가 변경 없음
- About 창 추가 변경 없음

## 검증 기준

- `swift test` 통과
- `git diff --check` 통과
- `make dev-verify` 통과
- 개발 앱 실행 후 설정 창이 열리고, `General`, `Automatic`, `Window Management` 화면이 사용 가능한지 확인
