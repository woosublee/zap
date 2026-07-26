# Zap 소비자 공개 출시 제품 로드맵 설계

## 배경

Zap v0.1.6은 Dock 순번 및 사용자 지정 글로벌 단축키로 앱을 실행·전환하고, Accessibility API로 전면 창을 배치·크기 조절하며, 전체 또는 현재 앱별로 글로벌 단축키를 중지할 수 있는 네이티브 macOS 유틸리티다.

현재 제품은 앱 실행, Finder 전환, 수동 앱 단축키, 18개 Window Management 동작, 단축키 일시중지, 앱별 단축키 제외, Sparkle 자동 업데이트까지 제공한다. 핵심 기능은 충분히 유용하지만 일반 소비자 대상 공개 출시에 필요한 설치 신뢰, 첫 실행 안내, 기존 기능 정확성, 오류 복구, 상시 CI와 지원 문서가 부족하다.

공개 최신 릴리스는 v0.1.6이며 현재 `main`과 일치한다. 이 로드맵을 GitHub에 반영하기 전 기준으로 GitHub Issues와 milestones는 아직 없었고, 지금까지의 제품 방향과 작업 이력은 PR, release note, `docs/superpowers/specs`, `docs/superpowers/plans`에 분산되어 있었다.

이 문서는 현재 제품 상태와 경쟁 제품의 검증된 패턴을 바탕으로, 소비자에게 전달되는 품질을 최우선으로 하면서 Zap이 장기적으로 확장할 기능을 순차 GitHub Issue와 milestone으로 정의한다.

## 확정된 제품 결정

1. 첫 도착점은 제한적 베타가 아니라 **소비자 공개 출시**다.
2. 첫 소비자 GA 버전은 **v0.2.0**이며, **Apple Silicon 전용**으로 지원 범위를 명확히 한다.
3. 주 배포 채널은 **Developer ID로 서명·공증한 DMG 직접 배포**다.
4. 로드맵은 **품질 게이트 우선** 방식으로 운영한다.
5. 승인된 로드맵은 실제 GitHub Issues와 milestones로 반영한다.
6. GitHub Project는 초기에는 만들지 않고 tracking issue, milestones, labels를 source of truth로 사용한다.
7. milestone에는 임의의 due date를 넣지 않는다. 날짜보다 exit gate 통과 여부로 다음 단계를 연다.

## 제품 정의

> Zap은 반복해서 사용하는 앱과 창을 근육 기억으로 빠르고 정확하게 제어하는 local-first, keyboard-first macOS 유틸리티다.

### 핵심 대상 사용자

- 브라우저, 터미널, IDE, 메신저, 메모 등 고정된 앱 집합을 하루 종일 전환하는 키보드 중심 사용자
- 브라우저, Finder, IDE처럼 한 앱의 여러 창을 사용하는 사용자
- 외부 모니터 연결·해제를 반복하며 창 배치를 다시 만드는 사용자
- IDE, 게임, 원격 데스크톱처럼 글로벌 단축키 충돌이 잦은 앱을 사용하는 사용자
- 앱 목록과 창 정보를 외부 서버에 보내지 않는 생산성 도구를 선호하는 사용자

### 우선순위 판단 원칙

1. 설치와 신뢰를 막는 문제
2. 잘못된 창 조작이나 설정 손실처럼 결과가 틀리는 문제
3. 동작하지 않는 이유를 알거나 복구하기 어려운 문제
4. 매일 반복되는 조작의 마찰
5. Zap의 제품 정의에 맞는 전략적 확장

### 비목표

- 전체 썸네일 창 스위처
- 마우스 가장자리 drag snapping
- 범용 검색 런처와 plugin marketplace
- 계정 기반 cloud sync
- AI 기반 레이아웃 추천
- 창 제목 정규식 등을 포함한 복잡한 앱별 규칙 엔진
- 초기 단계부터 제공하는 무제한 grid/layout 편집기

이 기능들은 AltTab, Rectangle, Raycast 등 기존 제품과 직접 경쟁하게 만들거나 새로운 권한·네트워크·인지 복잡도를 유발한다. Zap은 앱 단축키 반복, 명시적 workspace 저장·복원처럼 기존 제품 정의와 직접 연결되는 범위까지만 확장한다.

## 현재 제품 품질 판단

현재 Zap은 개인용 또는 소규모 신뢰 사용자 대상 베타로는 충분한 기능과 순수 로직 테스트를 갖췄다. 그러나 다음 문제 때문에 일반 소비자 대상 GA 출시는 보류해야 한다.

### 출시 차단 문제

- 공식 릴리스가 self-signed, non-notarized라 첫 실행에서 Gatekeeper 우회가 필요하다.
- 공식 빌드는 사실상 arm64지만 README와 최신 appcast가 지원 architecture를 명확히 표시하지 않는다.
- 첫 실행 안내 없이 Dock 및 Window Management 글로벌 단축키를 즉시 등록한다.
- Accessibility 권한이 없어도 사용할 수 없는 Window Management 단축키를 점유할 수 있다.
- PR/main CI와 branch protection이 없어 릴리스 실행 전까지 회귀를 발견하지 못할 수 있다.
- 실제 이전 버전에서 새 버전으로 Sparkle update가 성공하는지 검증하지 않는다.

### 핵심 정확성 문제

- Window History가 개별 창이 아닌 bundle identifier 단위라 같은 앱의 다른 창에 Undo를 적용할 수 있다.
- Undo/Redo stack이 실제 창 이동 성공 전에 변경되어 실패 시 history를 잃을 수 있다.
- shortcut recorder가 열려 있어도 기존 Zap global hotkey가 실행될 수 있다.
- Launch at Login UI가 `SMAppService` 실제 상태가 아니라 저장된 Boolean과 어긋날 수 있다.
- 홀수 크기 display에서 1px gap 또는 visible frame 밖의 target frame이 발생할 수 있다.
- 설정 decode 실패 시 일부 항목이 아니라 전체 목록이 조용히 기본값으로 돌아갈 수 있다.

### 소비자 경험 문제

- 첫 실행 onboarding, Download/Install, complete uninstall 안내가 없다.
- Accessibility prompt를 한 번 거절한 후 System Settings로 이동하는 복구 동작이 UI에 없다.
- Pause와 per-app disabled 상태가 지속되지만 남은 시간, 아이콘 상태, 전체 제외 앱 목록이 충분히 보이지 않는다.
- 오류가 raw enum, OSStatus, beep 또는 silent no-op으로 끝나는 경우가 많다.
- Automatic Dock shortcuts를 명시적으로 Off로 유지할 수 없다.
- `Fullscreen`이라는 이름이 실제 native fullscreen이 아니라 Maximize 동작을 가리킨다.
- README와 release note가 v0.1.6의 Pause 및 active-app toggle 기능을 충분히 설명하지 않는다.

## 로드맵 구조

| 순서 | Milestone | 목표 |
|---:|---|---|
| 0 | Roadmap & Engineering Baseline | Issue 운영, PR CI, 테스트, 버전 검증 기반 마련 |
| 1 | v0.1.7 — Reliability Foundation | 창·단축키·권한·설정의 잘못된 동작과 숨은 실패 제거 |
| 2 | v0.2.0 — Trusted Public Release | Apple Silicon용 공증 DMG와 소비자 첫 실행·신뢰 체계 완성 |
| 3 | v0.2.x — Daily-use Polish | 상태 가시성, 복구, 접근성, 용어와 발견성 개선 |
| 4 | v0.3.0 — Faster App Switching | 반복 앱 단축키, 같은 앱 창 순환, 설정 이식 |
| 5 | v0.4.0 — Named Workspaces | 여러 앱과 창 배치를 명시적으로 저장·수동 복원 |
| 6 | v0.5.0 — Context Restoration | 디스플레이 변화와 wake에 선택적으로 workspace 자동 복원 |

v0.2.0을 첫 소비자 GA 기준점으로 삼는다. 이후 milestone은 날짜가 아니라 선행 milestone의 exit gate를 통과하고, 모든 release blocker가 종료되며, 현재 milestone의 각 Issue가 완료되거나 이동 사유와 새 milestone을 명시한 뒤 시작한다.

## GitHub Issue 인벤토리

아래 R-ID는 Issue 생성 순서와 dependency 작성에 사용하는 안정적인 식별자다. 이 인벤토리는 roadmap design 수준의 요약이며 최종 GitHub Issue body 자체가 아니다. 실제 생성 전에는 모든 항목을 공통 Issue Body Template으로 확장하고, 해당 사항이 없는 필드도 `None`으로 명시하며, 현재 코드 permalink·관련 PR review·release/spec 중 하나 이상의 Evidence를 추가한다. 표시 문구의 R-ID는 실제 `#번호` 링크와 함께 쓰되, 재실행과 중복 방지를 위해 각 Issue에 `<!-- roadmap-id:R-01 -->` 형식의 marker를 영구 유지한다.

### Milestone 0 — Roadmap & Engineering Baseline

#### R-01 — `process: establish repository governance and release-blocker policy`

- Priority: P1
- Area: documentation, tests-ci
- User value: 제품 backlog와 출시 조건을 한곳에서 확인하고 완료되지 않은 review 항목이 사라지는 일을 방지한다.
- Scope:
  - issue forms와 PR template
  - priority, area, workflow labels
  - milestone 및 release-blocker 운영 규칙
  - bug report에 Zap/macOS version, Accessibility 상태, shortcut, display 구성을 수집하는 항목
- Acceptance criteria:
  - 새 bug와 feature request가 사용자 문제, 완료 조건, 기존 기능과의 차이를 포함한다.
  - 한 Issue에 type 1개, priority 1개, area 1~2개, status 1개를 적용하고 flag는 별도로 관리한다.
  - release blocker의 정의와 해제 조건을 문서화한다.
- Non-goals: 초기 GitHub Project 도입

#### R-02 — `build: add required PR and main-branch CI`

- Priority: P0
- Area: tests-ci, updates-release
- User value: 고장 난 빌드나 업데이트 경로가 공식 릴리스에 포함될 가능성을 줄인다.
- Scope:
  - pull request와 main push CI
  - `swift test`
  - `Tests/ScriptTests/generate-sparkle-appcast-tests.sh`
  - Debug/Release build와 bundle verification
  - branch protection 또는 repository ruleset
- Acceptance criteria:
  - CI failure가 merge를 차단한다.
  - force push와 branch deletion을 제한한다.
  - 수동 release workflow도 같은 검증 기준을 재사용한다.

#### R-03 — `test: establish behavioral smoke coverage for reliability blockers`

- Priority: P0
- Area: tests-ci, settings-ui
- User value: 창 history, shortcut recorder, 권한 변화의 실제 사용자 동작을 검증해 P0 정확성 수정을 안전하게 진행한다.
- Scope:
  - R-06, R-07, R-08에 필요한 최소 behavioral test harness
  - window-history integration, shortcut recorder, Accessibility permission refresh smoke coverage
  - 실제 macOS 통합 자동화가 불가능한 항목의 명시적 release checklist
- Acceptance criteria:
  - 테스트가 구현 문자열이 아니라 사용자 동작과 observable state를 검증한다.
  - 같은 앱의 두 창 history와 AX 적용 실패를 재현할 수 있다.
  - recorder가 기존 global hotkey를 실행하지 않는 흐름을 검증할 수 있다.
  - Accessibility grant/revoke에 따른 registration 변화를 검증할 수 있다.
- Non-goals: 저장소 전체의 `source.contains(...)` assertion 제거. 나머지 교체는 baseline 이후 별도 `tech-debt` Issue로 추적한다.
- Dependencies: R-02

#### R-04 — `build: make version metadata single-source and enforce monotonic releases`

- Priority: P1
- Area: updates-release
- User value: 새 버전이 업데이트 목록에 나타나지 않거나 이전 버전으로 회귀하는 사고를 방지한다.
- Scope:
  - version/build single source of truth
  - tag, bundle, appcast의 일치 검증
  - 최신 release보다 높은 SemVer와 Sparkle build number 검증
- Acceptance criteria:
  - Makefile과 Info.plist가 불일치할 수 없다.
  - version 또는 build number가 같거나 낮으면 release가 실패한다.
  - release metadata에 source commit, version, build, architecture를 기록한다.
- Dependencies: R-02

### Milestone 0 Exit Gate

- Issue form, PR template, labels, milestones 및 release-blocker 운영 규칙이 적용되어 있다.
- PR과 main push CI가 테스트, shell regression test, Debug/Release bundle verification을 실행한다.
- main merge는 필수 CI 실패 시 차단된다.
- R-06~R-08을 검증할 behavioral smoke baseline과 version metadata 검증이 통과한다.

### v0.1.7 — Reliability Foundation

#### R-05 — `fix: eliminate 1px gaps and out-of-bounds window frames`

- Priority: P1
- Area: window-management
- User value: 어떤 display 크기에서도 반쪽·코너·전체 배치가 빈틈이나 화면 밖 위치 없이 정확하게 맞는다.
- Acceptance criteria:
  - 홀수 width/height에서 양쪽 영역이 visible frame 전체를 정확히 덮는다.
  - full-size clamp 시 origin을 함께 보정한다.
  - multi-display visible frame과 menu bar/Dock inset을 포함한 regression test를 추가한다.
- Dependencies: R-02

#### R-06 — `fix: make window undo and redo transactional and window-scoped`

- Priority: P0
- Area: window-management, accessibility
- User value: 브라우저, Finder, IDE의 여러 창을 사용할 때 현재 창의 정확한 이전 위치만 복원한다.
- Scope:
  - per-session window identity
  - `peek → AX apply → success commit`
  - partial AX write 실패 시 원래 frame rollback 시도
- Acceptance criteria:
  - 같은 앱의 두 창이 독립된 undo/redo stack을 가진다.
  - 적용 실패 후 stack이 변경되지 않는다.
  - 닫히거나 재생성된 창의 history를 다른 창에 적용하지 않는다.
  - 전체 restore를 위한 future transaction interface를 막지 않는다.
- Dependencies: R-03

#### R-07 — `fix: make shortcut recording conflict-safe`

- Priority: P1
- Area: hotkeys, settings-ui
- User value: 단축키를 녹화하는 동안 앱 실행이나 창 이동이 발생하지 않고 충돌 원인을 저장 전에 알 수 있다.
- Scope:
  - Manual, Window, active-app toggle recorder가 공유하는 recording scope
  - recorder 표시 전 모든 Zap Carbon hotkey 해제
  - Zap 내부 shortcut catalog와 owner 표시
  - Replace 또는 Cancel UX
- Acceptance criteria:
  - recorder 취소, 저장, sheet close, Settings close에서 hotkey를 정확히 한 번 복원한다.
  - 기존 combo를 눌러도 해당 Zap action이 실행되지 않는다.
  - 등록 실패나 취소 시 기존 설정과 registration 상태를 유지한다.

#### R-08 — `fix: gate window hotkeys on Accessibility authorization and user opt-in`

- Priority: P0
- Area: hotkeys, accessibility
- User value: 사용할 수 없는 18개 Window Management shortcut이 첫 실행부터 다른 앱의 키를 점유하지 않는다.
- Scope:
  - Accessibility 상태와 explicit enable을 registration input에 반영
  - `Open Accessibility Settings`와 refresh UI
  - grant/revoke 시 registration 재계산
- Acceptance criteria:
  - 권한 또는 user opt-in이 없으면 Window hotkey 등록 수가 0이다.
  - 권한을 허용하면 앱 재활성화 시 자동으로 등록한다.
  - 권한을 취소하면 즉시 해제한다.
  - prompt가 다시 뜨지 않는 상태에서도 System Settings로 복구할 수 있다.

#### R-09 — `fix: synchronize Launch at Login with SMAppService state`

- Priority: P1
- Area: settings-ui
- User value: Zap UI가 실제 로그인 실행 상태를 정확히 표시한다.
- Acceptance criteria:
  - 앱 시작과 foreground 복귀 시 `SMAppService.mainApp.status`를 반영한다.
  - 등록/해제 실패 시 UI와 저장 상태를 이전 값으로 되돌린다.
  - `requiresApproval`, `enabled`, `notRegistered` 상태에 맞는 설명과 해결 동작을 제공한다.

#### R-10 — `perf: use one asynchronous Dock snapshot for display and activation`

- Priority: P1
- Area: app-launching
- User value: Dock shortcut과 menu Quick Launch가 즉시 반응하고 표시한 앱과 실제 실행 앱이 항상 같다.
- Scope:
  - background refresh와 immutable snapshot
  - Dock preference change debounce
  - hotkey 실행 경로의 cache lookup
- Acceptance criteria:
  - 메뉴 label과 activation이 같은 snapshot을 사용한다.
  - refresh 실패 시 마지막 정상 snapshot을 유지한다.
  - hotkey path에서 Dock plist 및 모든 Bundle을 동기적으로 다시 읽지 않는다.

#### R-11 — `feat: add privacy-safe diagnostics and support reporting`

- Priority: P1
- Area: settings-ui, hotkeys
- User value: Zap이 동작하지 않을 때 실패 종류를 이해하고 지원 요청에 필요한 환경 정보를 안전하게 전달한다.
- Scope:
  - OSLog categories: lifecycle, hotkey, Dock, AX, login item, update
  - registration, permission, unsupported window, app resolution 오류의 사용자 친화적 분류
  - support report 복사
- Acceptance criteria:
  - raw enum과 raw OSStatus를 사용자에게 직접 노출하지 않는다.
  - app name, bundle ID, URL 등은 기본 로그에서 private 처리한다.
  - version, build, macOS, architecture와 최근 오류 분류를 민감정보 없이 복사할 수 있다.
  - 구체적인 복구 action은 R-08, R-09, R-23, R-26 등 해당 기능 Issue가 소유한다.

#### R-12 — `fix: version settings persistence and recover partial corruption`

- Priority: P1
- Area: settings-ui
- User value: 설정 일부가 손상되어도 모든 shortcut을 잃지 않고 복구할 수 있다.
- Scope:
  - schema version
  - item-level decode와 migration
  - 손상 원본 backup
  - atomic write
- Acceptance criteria:
  - 일부 Manual/Window shortcut 손상 시 정상 항목은 유지한다.
  - fallback이나 migration이 발생하면 사용자와 diagnostics에 알린다.
  - future export/import가 사용할 configuration snapshot boundary를 제공한다.

#### R-13 — `fix: reevaluate shortcut pause across sleep, wake, and clock changes`

- Priority: P2
- Area: hotkeys
- User value: 잠자기 후 Pause가 이미 끝났는데도 Zap이 계속 멈춰 있는 혼란을 방지한다.
- Acceptance criteria:
  - wake와 significant time change에서 pause 상태를 재평가한다.
  - 만료된 pause는 즉시 registration을 복원한다.
  - 오래된 callback과 중복 timer가 상태를 되돌리지 못한다.

### v0.1.7 Exit Gate

- 알려진 경로에서 다른 창에 Undo가 적용되지 않는다.
- 사용할 수 없는 Window Management hotkey를 등록하지 않는다.
- shortcut recorder가 기존 Zap action을 실행하지 않는다.
- Launch at Login UI와 실제 시스템 상태가 일치한다.
- window geometry가 odd-sized visible frame을 정확히 채운다.
- 설정 일부가 손상되어도 정상 shortcut과 설정은 유지된다.
- 핵심 오류는 silent no-op이나 raw error가 아니라 분류된 사용자 메시지와 support report에 남는다.

### v0.2.0 — Trusted Public Release

#### R-14 — `release: declare and verify Apple Silicon-only compatibility`

- Priority: P0
- Area: updates-release, documentation
- User value: 다운로드 전에 지원 Mac인지 알 수 있고 호환되지 않는 update 제안을 받지 않는다.
- Acceptance criteria:
  - app executable과 nested Sparkle executable이 arm64인지 CI에서 검사한다.
  - README, release note, download 안내에 Apple Silicon requirement를 표시한다.
  - appcast에 minimum system version과 hardware requirements를 포함한다.

#### R-15 — `release: sign and notarize production DMGs with Developer ID`

- Priority: P0
- Area: updates-release
- User value: Gatekeeper 우회 없이 일반 macOS 앱처럼 신뢰하고 설치할 수 있다.
- Scope:
  - Developer ID Application signing
  - Hardened Runtime와 secure timestamp
  - notarization, stapling, Gatekeeper assessment
- Acceptance criteria:
  - app, Sparkle components, DMG가 적절한 identity로 서명된다.
  - `notarytool submit --wait`, `stapler validate`, `spctl --assess`가 통과한다.
  - notarization 실패 시 release를 공개하지 않는다.
  - 깨끗한 macOS user account에서 `Open Anyway` 없이 실행한다.
- Dependencies: R-14
- External prerequisites:
  - active Apple Developer Program membership
  - Developer ID Application certificate
  - notarization에 필요한 App Store Connect credential

#### R-16 — `release: make publication main-only, atomic, and update-safe`

- Priority: P0
- Area: updates-release
- User value: 잘못된 branch, 부분 release, 동시에 실행된 release 때문에 업데이트가 깨지는 일을 방지한다.
- Scope:
  - main-only release
  - concurrency
  - draft upload, verification, publish
  - complete rollback
  - previous release fixture에서 Sparkle update
- Acceptance criteria:
  - 모든 asset과 appcast가 검증된 후에만 latest release가 된다.
  - 실패 시 tag, draft/release, partial asset을 일관되게 정리한다.
  - 공개 후 latest appcast와 enclosure URL을 다시 검증한다.
  - N-1 공개 버전에서 새 버전으로 update하고 launch/version을 확인한다.
- Dependencies: R-02, R-04, R-15

#### R-17 — `security: verify release tooling and publish artifact provenance`

- Priority: P1
- Area: updates-release
- User value: 다운로드한 앱과 release tool이 검토된 source에서 생성되었음을 검증하기 쉽다.
- Acceptance criteria:
  - Sparkle tool archive checksum을 실행 전에 검증한다.
  - checksum mismatch는 signing secret을 사용하기 전에 실패한다.
  - runner와 Xcode/Swift version 정책을 명시한다.
  - release asset SHA-256와 artifact provenance를 게시한다.
  - GitHub release asset immutability를 활성화한다.
  - release tag는 검증 가능한 signed annotated tag로 생성한다.
- Dependencies: R-02

#### R-18 — `feat: add a first-run activation checklist`

- Priority: P0
- Area: settings-ui, accessibility
- User value: 메뉴바 앱을 실행했지만 무엇을 해야 하는지 모르는 상태를 방지하고 첫 성공 시간을 줄인다.
- Scope:
  - 현재 Dock 1–9 mapping 확인
  - Automatic modifier 확인과 시험
  - Window Management explicit opt-in
  - 필요할 때만 Accessibility 요청
  - Launch at Login 선택
- Acceptance criteria:
  - 최초 실행에만 Getting Started 화면을 연다.
  - Skip과 Complete를 제공하고 General에서 다시 열 수 있다.
  - 완료 여부는 local-only로 저장한다.
  - 깨끗한 macOS 계정에서 Zap 최초 실행을 시작점, mapped app이 frontmost가 된 시점을 종료점으로 측정해 180초 이내에 통과한다.
- Dependencies: R-08

#### R-19 — `ux: ship a consumer-ready install and complete uninstall flow`

- Priority: P1
- Area: updates-release, documentation
- User value: 다운로드, 설치, 첫 실행, 삭제를 혼란 없이 완료한다.
- Acceptance criteria:
  - DMG에 `/Applications` symlink와 drag-to-install 안내를 제공한다.
  - DMG에서 직접 실행하지 않도록 설명한다.
  - Download/Install/First Run/Troubleshooting/Uninstall 문서를 제공한다.
  - uninstall에서 app, Login Item, UserDefaults, Accessibility permission 정리 방법을 설명한다.
- Dependencies: R-15

#### R-20 — `trust: publish privacy, support, security, license, and third-party notices`

- Priority: P0
- Area: documentation
- User value: Accessibility와 global hotkey 권한을 요청하는 앱을 신뢰할 근거와 문제 신고 경로를 얻는다.
- Scope:
  - `PRIVACY.md`
  - `SUPPORT.md`
  - `SECURITY.md`
  - project LICENSE
  - Sparkle third-party notice
  - About의 Support, Report a Bug, Privacy, Release Notes 링크
- Acceptance criteria:
  - Dock plist, frontmost app, window metadata, UserDefaults, Accessibility 사용 목적을 설명한다.
  - analytics/crash collection 미사용 여부와 GitHub/Sparkle update network request를 설명한다.
  - private vulnerability report 경로를 제공한다.

#### R-21 — `docs: publish complete release notes and current consumer documentation`

- Priority: P1
- Area: documentation, updates-release
- User value: 설치와 업데이트 전 무엇이 바뀌고 어떤 권한과 호환성 조건이 있는지 판단할 수 있다.
- Acceptance criteria:
  - Features, Fixes, Security, Known Issues, Compatibility를 구분한 CHANGELOG 또는 release note source를 둔다.
  - appcast에 description 또는 release notes link를 포함한다.
  - v0.1.6의 Pause, per-app disable, active-app toggle과 숨은 window ratio cycling을 문서화한다.
  - README Recent updates 수동 복제 대신 canonical release note로 연결한다.
- Dependencies: R-16

### v0.2.0 GA Exit Gate

- `Open Anyway` 없이 설치하고 실행할 수 있다.
- 다운로드 전에 Apple Silicon 전용임을 알 수 있다.
- 신규 사용자가 3분 안에 첫 앱 전환을 성공할 수 있다.
- Window Management는 user opt-in과 Accessibility 승인 전까지 key를 점유하지 않는다.
- 설치, 업데이트, 삭제, 지원, privacy, security 신고 경로가 존재한다.
- N-1 설치본에서 실제 Sparkle update가 성공한다.

### v0.2.x — Daily-use Polish

#### R-22 — `feat: make pause and per-app disabled states continuously visible`

- Priority: P1
- Area: hotkeys, settings-ui
- User value: Zap이 반응하지 않는 이유와 자동 재개 시점을 즉시 이해한다.
- Acceptance criteria:
  - menu에 pause remaining time을 표시한다.
  - menu bar icon이 normal, paused, current-app-disabled 상태를 구분한다.
  - 재실행 후 pause가 복원된 경우 이유와 Resume 동작을 보여준다.

#### R-23 — `feat: manage disabled applications in Settings`

- Priority: P1
- Area: settings-ui, hotkeys
- User value: 어느 앱에서 Zap을 껐는지 한곳에서 확인하고 복구한다.
- Acceptance criteria:
  - disabled app name과 bundle identifier를 표시한다.
  - per-app Enable과 Enable All을 제공한다.
  - 삭제되거나 이름이 바뀐 앱도 정리할 수 있다.
  - menu bar와 같은 data source를 사용한다.
- Dependencies: R-22

#### R-24 — `feat: add a configurable global pause and resume shortcut`

- Priority: P2
- Area: hotkeys, settings-ui
- User value: 게임, IDE, 원격 데스크톱 진입 전 menu를 열지 않고 Zap 전체를 중지하거나 재개한다.
- Acceptance criteria:
  - pause 상태에서도 동작 가능한 dedicated control hotkey를 제공한다.
  - 다른 shortcut과의 충돌을 R-07 방식으로 설명한다.
  - unpaused 상태에서 control hotkey를 누르면 indefinite pause로 전환한다.
  - timed 또는 indefinite pause 상태에서 control hotkey를 누르면 모든 pause를 해제한다.
  - menu에서 새 timed pause를 선택하면 기존 timed 또는 indefinite pause를 대체한다.
- Dependencies: R-07

#### R-25 — `feat: add a persistent enable switch for Automatic Dock shortcuts`

- Priority: P1
- Area: app-launching, settings-ui
- User value: 숫자 Dock shortcut을 사용하지 않는 사용자가 기능을 명확하고 영구적으로 끌 수 있다.
- Acceptance criteria:
  - modifier 선택과 별도의 explicit On/Off를 제공한다.
  - Off가 재실행 후 유지된다.
  - Off 상태에서는 관련 hotkey를 등록하지 않는다.

#### R-26 — `fix: recover moved Manual apps and prevent duplicate shortcuts`

- Priority: P2
- Area: app-launching, settings-ui
- User value: 앱 재설치나 이동 후에도 shortcut을 복구하고 중복 설정을 만들지 않는다.
- Acceptance criteria:
  - 저장 URL이 없으면 bundle identifier로 설치 위치를 다시 찾는다.
  - 동일 bundle identifier의 중복 추가를 막는다.
  - 앱 선택 직후 shortcut recorder를 이어서 열 수 있다.
  - 해결할 수 없는 앱에는 reconnect 또는 remove를 제공한다.
- Dependencies: R-10

#### R-27 — `ux: align window action names, explanations, and destructive controls`

- Priority: P2
- Area: window-management, settings-ui
- User value: 명칭과 실제 결과가 일치하고 숨은 반복 동작을 쉽게 학습한다.
- Acceptance criteria:
  - 현재 visible frame 최대화 동작을 `Fullscreen` 대신 `Maximize`로 표시한다.
  - Half/Corner 반복 시 1/2, 2/3, 1/3 순환과 Next Third 동작을 UI에서 설명한다.
  - Reset to Defaults 전에 확인과 변경 요약을 제공한다.

#### R-28 — `a11y: support resizable Settings, VoiceOver, keyboard access, and Reduce Motion`

- Priority: P1
- Area: accessibility, settings-ui
- User value: 큰 글꼴, VoiceOver, Full Keyboard Access, motion sensitivity 환경에서도 설정을 완료한다.
- Acceptance criteria:
  - Settings 기본 크기는 820×640을 유지하고 minimum size는 720×560으로 설정한다.
  - 720×560과 macOS 최대 accessibility text size에서 sidebar, permission card, shortcut rows, recorder의 내용이 잘리지 않는다.
  - shortcut capture view에 role, label, value, hint를 제공한다.
  - modifier selection을 의미 있는 문장으로 읽는다.
  - Reduce Motion이 켜지면 recorder의 반복 pulse를 제거한다.
  - VoiceOver와 Full Keyboard Access로 sidebar 이동, permission action, shortcut recorder 열기·취소·저장을 완료하는 smoke test를 수행한다.

#### R-29 — `i18n: add localization-ready strings and keyboard-layout-aware key labels`

- Priority: P2
- Area: localization, settings-ui
- User value: 비-US keyboard layout에서도 화면에 표시된 key와 실제 입력이 일치한다.
- Acceptance criteria:
  - String Catalog 또는 equivalent resource pipeline을 추가한다.
  - 동적 문장을 localization 가능한 단위로 구성한다.
  - 현재 keyboard layout을 사용해 key label을 표시한다.
  - US ANSI, Korean 2-set, Japanese JIS, French AZERTY layout을 검증한다.
- Non-goals: v0.2.x에서 영어 이외의 전체 UI 번역을 출시하는 것
- Dependencies: R-28

#### R-30 — `chore: replace the legacy SNAP Carbon hotkey signature`

- Priority: P3
- Area: hotkeys
- User value: 실행 binary와 내부 diagnostics까지 정식 제품명 Zap으로 일관되게 유지한다.
- Acceptance criteria:
  - Carbon signature `SNAP` 잔재를 Zap identifier로 교체한다.
  - 기존 registration과 dispatch regression test가 통과한다.

### v0.2.x Exit Gate

- Pause 또는 per-app disable 때문에 Zap이 멈춘 상태를 즉시 알아볼 수 있다.
- 사용자가 Settings에서 disabled app, permission, registration failure를 스스로 복구할 수 있다.
- 핵심 Settings flow가 VoiceOver와 keyboard-only interaction으로 가능하다.
- UI에 표시되는 action 이름과 실제 결과가 일치한다.

### v0.3.0 — Faster App Switching

#### R-31 — `feat: add a configurable repeated app-shortcut action`

- Priority: P1
- Area: app-launching, settings-ui
- User value: 같은 앱 shortcut을 다시 눌러 앱을 숨기고 직전 작업으로 빠르게 돌아간다.
- Acceptance criteria:
  - `When the target app is already frontmost` 설정을 제공한다.
  - 첫 버전은 `Activate only`와 `Hide app`을 지원한다.
  - 기존 설치 기본값은 `Activate only`다.
  - Automatic Dock과 Manual shortcut에 같은 정책을 적용한다.
  - Finder는 repeated-action 정책에서 제외하고 기존 reopen behavior를 항상 사용한다.

#### R-32 — `feat: cycle same-app windows on repeated app shortcuts`

- Priority: P1
- Area: app-launching, accessibility
- User value: 브라우저, 터미널, Finder 등 같은 앱의 여러 창을 별도 단축키 없이 순환한다.
- Acceptance criteria:
  - repeated action option에 `Cycle Windows`를 추가한다.
  - 일반 top-level window만 예측 가능한 MRU 순서로 순환한다.
  - sheet와 system dialog를 제외한다.
  - 첫 버전은 current Space의 window부터 지원한다.
  - Accessibility가 없거나 조회가 실패하면 기존 activate 동작으로 fallback한다.
  - Screen Recording 권한을 요구하지 않는다.
- Dependencies: R-06, R-31

#### R-33 — `feat: export and import a versioned Zap configuration`

- Priority: P1
- Area: settings-ui
- User value: Mac 교체나 재설치 후 많은 shortcut을 다시 설정하지 않는다.
- Acceptance criteria:
  - schema version이 있는 JSON으로 export한다.
  - runtime pause expiration 같은 일시 상태는 제외한다.
  - import 전에 변경 항목과 누락 앱을 preview한다.
  - Manual shortcut은 bundle identifier, Window shortcut은 action identifier, singleton preference는 setting key를 merge identity로 사용한다.
  - Merge는 기존 값을 유지하고 없는 항목만 추가하며, 충돌 항목은 preview에서 건너뛴 것으로 표시한다.
  - Replace는 preview 승인 후 export 대상 설정 전체를 원자적으로 교체한다.
  - 지원하지 않는 future schema는 기존 설정을 변경하지 않고 거부한다.
  - 실패 시 부분 적용하지 않는다.
  - network와 account를 사용하지 않는다.
- Dependencies: R-12

### v0.3.0 Exit Gate

- 앱 shortcut 반복으로 현재 앱을 숨기거나 같은 앱의 원하는 창까지 이동할 수 있다.
- 기존 사용자 동작은 opt-in 전까지 바뀌지 않는다.
- 설정을 versioned local file로 안전하게 이동할 수 있다.

### v0.4.0 — Named Workspaces

#### R-34 — `core: enumerate and identify eligible application windows safely`

- Priority: P1
- Area: window-management, accessibility
- User value: 여러 앱과 여러 창을 안전하게 workspace에 포함할 기반을 만든다.
- Acceptance criteria:
  - 일반 user window를 열거하고 stable session identity를 부여한다.
  - matching descriptor는 app bundle identifier, AX role/subrole, optional application-provided AXIdentifier, session window identity로 구성한다.
  - restore matching은 exact session identity → stable AXIdentifier → 해당 앱의 단일 eligible candidate 순서로 시도한다.
  - 후보가 둘 이상이고 stable match가 없으면 추측하지 않고 `ambiguous match`로 보고한다.
  - sheet, system dialog, 비표준 window를 명확한 정책으로 제외한다.
  - display와 normalized frame을 계산한다.
  - window title은 identity나 persistence에 사용하지 않는다.
- Dependencies: R-06

#### R-35 — `feat: save named workspace presets locally`

- Priority: P1
- Area: window-management, settings-ui
- User value: Coding, Writing, Meeting 등 반복하는 앱·창 배치를 명시적으로 저장한다.
- Acceptance criteria:
  - preset name, window matching descriptor, display information, normalized frame을 저장한다.
  - window title은 저장하지 않는다.
  - stable AXIdentifier가 없는 multi-window app은 restore 시 ambiguous가 될 수 있음을 Save preview에서 알린다.
  - preset schema version을 둔다.
  - duplicate name, missing app, unsupported window를 설명한다.
  - 모든 data는 local-only다.
- Dependencies: R-33, R-34

#### R-36 — `feat: restore workspace presets with partial-failure reporting and global undo`

- Priority: P1
- Area: window-management, accessibility
- User value: 여러 앱과 창을 한 번의 action으로 복원하고 실패한 항목만 이해한다.
- Acceptance criteria:
  - exact 또는 unambiguous match가 확인된 app/window만 복원한다.
  - 누락, ambiguous match, 이동 거부, display mismatch를 항목별 결과로 보고한다.
  - 성공적으로 이동한 창만 하나의 global undo transaction에 commit한다.
  - 실패하거나 모호한 창은 기존 위치와 history를 변경하지 않는다.
  - restore 전체를 한 번에 Undo할 수 있다.
  - Settings와 configurable global shortcut에서 수동 실행한다.
  - display change와 wake 자동 trigger는 포함하지 않는다.
- Dependencies: R-35

### v0.4.0 Exit Gate

- workspace는 사용자가 명시적으로 Save/Restore한다.
- partial failure가 기존 layout 또는 history를 손상하지 않는다.
- 전체 restore를 한 번에 되돌릴 수 있다.

### v0.5.0 — Context Restoration

#### R-37 — `feat: match workspace presets to display configurations`

- Priority: P2
- Area: window-management
- User value: 노트북 단독, 집, 사무실 display 구성을 구분해 올바른 preset을 선택한다.
- Acceptance criteria:
  - display configuration을 안정적으로 식별한다.
  - preset을 특정 configuration과 연결한다.
  - match가 없거나 모호하면 아무 작업도 하지 않는다.
  - display identity 변화에 대한 migration 또는 재연결 UX를 제공한다.
- Dependencies: R-35

#### R-38 — `feat: auto-restore workspaces after display changes and wake`

- Priority: P2
- Area: window-management, accessibility
- User value: 외부 모니터 연결·해제와 wake 이후 무너진 창 배치를 자동으로 복구한다.
- Acceptance criteria:
  - preset별 explicit opt-in이 필요하다.
  - display change 후 2초 동안 debounce한다.
  - debounce 기간에 user-originated AX move/resize event가 관찰되면 이번 auto-restore를 취소한다.
  - restore가 진행 중이면 새 trigger를 queue하지 않고 현재 실행 종료 후 최신 display state만 한 번 재평가한다.
  - wake/unlock 적용은 별도 option이다.
  - 자동 app launch는 기본 Off다.
  - 결과를 알리고 전체 작업을 한 번에 Undo할 수 있다.
- Dependencies: R-36, R-37

### v0.5.0 Exit Gate

- 자동 복원은 기본 Off다.
- 사용자가 선택한 display configuration에서만 실행된다.
- 자동 실행은 debounce되고 중복되지 않으며 되돌릴 수 있다.

## GitHub 운영 구조

### Tracking Issue

`Zap Product Roadmap` Issue를 하나 만들고 다음을 포함한다.

- 제품 정의와 비목표
- milestone 순서
- 각 milestone exit gate
- 실제 GitHub Issue checklist
- 현재 active milestone과 다음 `status:ready` Issue
- 제품 결정 변경 기록

실제 Issue 번호가 발급된 뒤 tracking issue의 표시 목록은 `R-01 — #번호` 형식으로 갱신하고, 각 Issue body의 숨은 roadmap marker는 유지한다.

### Milestones

1. Roadmap & Engineering Baseline
2. v0.1.7 — Reliability Foundation
3. v0.2.0 — Trusted Public Release
4. v0.2.x — Daily-use Polish
5. v0.3.0 — Faster App Switching
6. v0.4.0 — Named Workspaces
7. v0.5.0 — Context Restoration

### Labels

Type은 기존 label을 다음 규칙으로 사용한다.

- 사용자에게 잘못된 동작을 수정하는 Issue → `bug`
- 문서만 변경하는 Issue → `documentation`
- 나머지 roadmap 작업 → `enhancement`

Priority:

- `priority:P0`
- `priority:P1`
- `priority:P2`
- `priority:P3`

Area:

- `area:hotkeys`
- `area:window-management`
- `area:app-launching`
- `area:settings-ui`
- `area:accessibility`
- `area:updates-release`
- `area:tests-ci`
- `area:localization`
- `area:documentation`

Status는 한 Issue에 하나만 적용한다.

- `status:planned`
- `status:needs-design`
- `status:blocked`
- `status:ready`
- `status:in-progress`

Flags는 status와 별도로 필요한 만큼 적용한다.

- `release-blocker`
- `tech-debt`
- `roadmap`

초기 상태는 active milestone에서 즉시 실행 가능한 Issue를 `status:ready`, 실제 dependency가 미완료인 Issue를 `status:blocked`, 미래 milestone의 범위가 확정된 Issue를 `status:planned`, 추가 제품 설계가 필요한 Issue를 `status:needs-design`으로 배정한다.

### Issue Body Template

모든 roadmap Issue는 생성 전에 아래 순서로 완성한다. 해당 사항이 없는 필드는 생략하지 않고 `None`이라고 적는다.

1. 숨은 `roadmap-id` marker
2. User problem
3. Product value
4. Scope
5. Acceptance criteria
6. Dependencies
7. External prerequisites
8. Non-goals
9. Evidence
   - current code permalink 또는 `file:line`
   - 관련 PR review
   - 관련 release/spec
10. Milestone exit-gate impact 또는 `Non-gating`

### 실행 규칙

- 기본적으로 다음 Issue 하나만 `status:ready`로 둔다.
- 서로 독립적인 문서·릴리스·UI 작업만 병렬로 ready 상태를 허용한다.
- dependency가 완료되면 `status:blocked`를 `status:ready` 또는 `status:planned`로 전환한다.
- 작업을 시작하면 `status:in-progress`로 전환한다.
- P0는 해당 milestone의 release 전에 반드시 완료한다.
- 다음 milestone은 exit gate 통과, 모든 release blocker 종료, 현재 milestone의 각 Issue 완료 또는 이동 사유·새 milestone 기록이 모두 충족된 뒤 시작한다.
- 구현 중 발견한 소비자 신뢰성 문제는 다음 milestone으로 미루지 않고 현재 milestone의 release blocker 여부를 판단한다.
- milestone 완료 시 단위 테스트만이 아니라 실제 install, permission, hotkey, update, window flow로 exit gate를 검증한다.

## 실제 GitHub 반영 순서

1. 이 설계 문서를 review하고 확정한다.
2. 기존 labels, milestones, open/closed Issues와 tracking issue를 preflight한다.
3. labels와 milestones는 exact name 기준으로 없을 때만 생성하고, 이미 있으면 재사용한다.
4. R-01부터 R-38까지 공통 Issue Body Template을 완성하고 `roadmap-id` marker를 부여한다.
5. open/closed Issue에서 같은 marker를 검색하고 존재하지 않는 R-ID만 생성한다.
6. R-ID→Issue 번호 mapping으로 dependencies, milestone exit-gate impact와 checklist를 갱신한다.
7. `Zap Product Roadmap` tracking issue를 exact title과 marker 기준으로 생성하거나 갱신한다.
8. Issue 수, 중복 marker, milestone 배정, labels, dependency link, exit gate 누락을 검증한다.
9. R-01과 R-02를 첫 `status:ready` Issue로 지정하고 나머지는 dependency와 milestone에 따라 `status:blocked` 또는 `status:planned`로 지정한다.

## 검증 기준

로드맵 반영 작업은 다음을 모두 확인한 후 완료로 간주한다.

- 7개 milestone이 정확한 이름으로 존재한다.
- 38개 roadmap Issue가 중복 없이 존재한다.
- 모든 Issue에 type, priority, area, status label과 milestone이 배정되고 필요한 flag가 별도로 적용된다.
- 모든 R-ID dependency가 실제 Issue 링크로 연결되고 external prerequisite와 구분된다.
- tracking issue에 38개 Issue와 7개 exit gate가 포함된다.
- P0 Issue가 명확히 표시된다.
- 이미 구현된 Window Management, Sparkle, Pause, per-app disable, active-app toggle을 신규 기능 Issue로 중복 생성하지 않는다.
- 공개 repository의 기존 PR과 release에 대한 근거 링크를 유지한다.
