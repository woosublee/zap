# Zap GitHub Product Roadmap Rollout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 승인된 Zap 제품 로드맵을 `woosublee/zap`의 labels, 7개 milestones, 38개 canonical Issues, dependency links, `Zap Product Roadmap` tracking issue로 중복 없이 반영하고 검증한다.

**Architecture:** GitHub Issues를 최종 source of truth로 사용하되, 각 Issue body의 `<!-- roadmap-id:R-XX -->` marker를 안정적인 외부 ID로 유지한다. 실행은 preflight → labels upsert → milestones upsert → R-ID 순차 Issue upsert → tracking issue upsert → 전체 불변조건 검증 순서로 진행하며, 기존 marker가 있으면 생성하지 않고 canonical title/body/labels/milestone으로 갱신한다.

**Tech Stack:** GitHub CLI `gh`, GitHub REST API, Bash/zsh, Python 3 standard library, `jq`, GitHub Issues/Labels/Milestones

## Global Constraints

- 기준 설계 문서: `/Users/woosublee/Documents/dev/zap/docs/superpowers/specs/2026-07-27-zap-product-roadmap-design.md`
- 대상 repository는 반드시 `woosublee/zap`이어야 한다.
- 제품명은 항상 `Zap`을 사용한다. `Snap`은 R-30의 실제 legacy Carbon signature를 설명할 때만 사용한다.
- 첫 소비자 GA milestone은 `v0.2.0 — Trusted Public Release`다.
- 첫 GA의 지원 architecture는 Apple Silicon 전용이다.
- roadmap은 품질 게이트 우선 순서를 유지한다.
- 정확히 7개 milestone과 R-01~R-38의 38개 roadmap Issues를 관리한다.
- 각 roadmap Issue에는 정확히 하나의 `roadmap-id` marker가 있어야 한다.
- 같은 marker의 open/closed Issue가 이미 있으면 새 Issue를 만들지 않는다.
- Issue body에는 User problem, Product value, Scope, Acceptance criteria, Dependencies, External prerequisites, Non-goals, Evidence, Milestone exit-gate impact를 모두 넣고 해당 사항이 없으면 `None`을 쓴다.
- 모든 R-ID dependency는 해당 GitHub Issue 링크로 기록한다. External prerequisite와 섞지 않는다.
- type label은 `bug`, `documentation`, `enhancement` 중 하나만 적용한다.
- priority label은 `priority:P0`~`priority:P3` 중 하나만 적용한다.
- area label은 1~2개만 적용한다.
- status label은 `status:planned`, `status:needs-design`, `status:blocked`, `status:ready`, `status:in-progress` 중 하나만 적용한다.
- `release-blocker`, `tech-debt`, `roadmap`은 status가 아닌 flag다.
- 첫 ready Issues는 R-01과 R-02다.
- milestone due date는 설정하지 않는다.
- GitHub Project는 만들지 않는다.
- Issue, milestone, label, tracking issue의 생성과 편집은 외부 공개 변경이다. 각 apply task 시작 전에 현재 repository와 marker 상태를 다시 확인한다.
- 이 계획은 제품 기능 R-01~R-38을 구현하지 않는다. GitHub roadmap metadata 반영만 수행한다.
- source code는 수정하지 않는다. 실행 중 필요한 body, mapping, snapshot 파일은 `/tmp/zap-roadmap-sync` 아래에만 만든다.
- GitHub 변경 task에는 git commit이 없다. 로컬 repository에는 실행 산출물을 추가하지 않는다.

---

## File and External Resource Responsibility Map

### Read-only local files

- `/Users/woosublee/Documents/dev/zap/docs/superpowers/specs/2026-07-27-zap-product-roadmap-design.md`
  - R-01~R-38의 canonical Product value, Scope, Acceptance criteria, Dependencies, External prerequisites, Non-goals, milestone exit gates를 제공한다.
- `/Users/woosublee/Documents/dev/zap/README.md`
- `/Users/woosublee/Documents/dev/zap/.github/workflows/release.yml`
- `/Users/woosublee/Documents/dev/zap/Makefile`
- `/Users/woosublee/Documents/dev/zap/Info.plist`
- `/Users/woosublee/Documents/dev/zap/Sources/**`
- `/Users/woosublee/Documents/dev/zap/Tests/**`
  - 각 Issue의 Evidence permalink가 현재 HEAD `59498cdcb46fe1b42ea25967ee7986c2618b41a1`과 일치하는지 확인한다.

### Temporary runtime files

- `/tmp/zap-roadmap-sync/preflight.json`
  - repository와 authenticated user identity
- `/tmp/zap-roadmap-sync/labels.json`, `/tmp/zap-roadmap-sync/milestones.json`, `/tmp/zap-roadmap-sync/issues.json`
  - apply 전 GitHub metadata snapshots
- `/tmp/zap-roadmap-sync/milestone-map.json`
  - canonical milestone title과 REST API milestone number
- `/tmp/zap-roadmap-sync/issue-map.json`
  - `R-01`~`R-38` 및 `TRACKING`의 Issue number와 URL
- `/tmp/zap-roadmap-sync/bodies/R-XX.md`
  - canonical Issue bodies
- `/tmp/zap-roadmap-sync/tracking.md`
  - tracking Issue body
- `/tmp/zap-roadmap-sync/verification.json`
  - 최종 검증 counts와 누락 목록

### GitHub resources modified

- Repository labels
- 7 milestones
- 38 roadmap Issues
- 1 `Zap Product Roadmap` tracking Issue

---

## Canonical Label Definitions

| Label | Color | Description |
|---|---|---|
| `priority:P0` | `B60205` | GA 또는 release를 차단하는 최우선 작업 |
| `priority:P1` | `D93F0B` | 핵심 사용자 흐름의 정확성, 복구, 높은 가치 작업 |
| `priority:P2` | `FBCA04` | 일반 제품 개선 |
| `priority:P3` | `0E8A16` | 낮은 우선순위 polish |
| `area:hotkeys` | `1D76DB` | 글로벌 단축키 등록, 충돌, pause |
| `area:window-management` | `5319E7` | 창 위치, 크기, history, workspace |
| `area:app-launching` | `0052CC` | Dock, Finder, Manual 앱 실행과 전환 |
| `area:settings-ui` | `C5DEF5` | Settings와 사용자 설정 흐름 |
| `area:accessibility` | `7057FF` | Accessibility 권한, AX API, 보조 기술 |
| `area:updates-release` | `006B75` | Sparkle, signing, notarization, 배포 |
| `area:tests-ci` | `0E8A16` | 테스트, CI, branch protection |
| `area:localization` | `BFD4F2` | 문자열 localization과 keyboard layout |
| `area:documentation` | `0075CA` | 소비자, 지원, privacy, security 문서 |
| `status:planned` | `D4C5F9` | 미래 milestone에 계획된 작업 |
| `status:needs-design` | `FBCA04` | 구현 전 추가 제품 설계가 필요한 작업 |
| `status:blocked` | `B60205` | 명시적 dependency가 완료되지 않은 작업 |
| `status:ready` | `0E8A16` | 현재 바로 시작할 수 있는 작업 |
| `status:in-progress` | `1D76DB` | 현재 구현 중인 작업 |
| `release-blocker` | `B60205` | milestone release 전에 반드시 종료해야 하는 작업 |
| `tech-debt` | `6A737D` | 기능 변경보다 구조·유지보수 부채를 줄이는 작업 |
| `roadmap` | `5319E7` | 승인된 Zap 제품 roadmap 항목 |

Existing `bug`, `documentation`, `enhancement` labels are reused and not recolored unless they are missing.

---

## Canonical Milestones

| Order | Title | Description |
|---:|---|---|
| 0 | `Roadmap & Engineering Baseline` | Issue 운영, PR CI, behavioral smoke baseline, version 검증 기반을 마련한다. |
| 1 | `v0.1.7 — Reliability Foundation` | 창·단축키·권한·설정의 잘못된 동작과 숨은 실패를 제거한다. |
| 2 | `v0.2.0 — Trusted Public Release` | Apple Silicon용 Developer ID 공증 DMG와 소비자 첫 실행·신뢰 체계를 완성한다. |
| 3 | `v0.2.x — Daily-use Polish` | 상태 가시성, 복구, 접근성, 용어와 발견성을 개선한다. |
| 4 | `v0.3.0 — Faster App Switching` | 반복 앱 단축키, 같은 앱 창 순환, 설정 이식을 제공한다. |
| 5 | `v0.4.0 — Named Workspaces` | 여러 앱과 창 배치를 명시적으로 저장하고 수동 복원한다. |
| 6 | `v0.5.0 — Context Restoration` | display 변화와 wake에 선택적으로 workspace를 자동 복원한다. |

All milestones remain open and have no `due_on` value.

---

## Canonical Issue Metadata Matrix

| ID | Type | Priority | Areas | Initial status | Flags | Milestone | Dependencies |
|---|---|---|---|---|---|---|---|
| R-01 | enhancement | P1 | documentation, tests-ci | ready | roadmap | Roadmap & Engineering Baseline | None |
| R-02 | enhancement | P0 | tests-ci, updates-release | ready | roadmap, release-blocker | Roadmap & Engineering Baseline | None |
| R-03 | enhancement | P0 | tests-ci, settings-ui | blocked | roadmap, release-blocker | Roadmap & Engineering Baseline | R-02 |
| R-04 | enhancement | P1 | updates-release | blocked | roadmap | Roadmap & Engineering Baseline | R-02 |
| R-05 | bug | P1 | window-management | blocked | roadmap | v0.1.7 — Reliability Foundation | R-02 |
| R-06 | bug | P0 | window-management, accessibility | blocked | roadmap, release-blocker | v0.1.7 — Reliability Foundation | R-03 |
| R-07 | bug | P1 | hotkeys, settings-ui | planned | roadmap | v0.1.7 — Reliability Foundation | None |
| R-08 | bug | P0 | hotkeys, accessibility | planned | roadmap, release-blocker | v0.1.7 — Reliability Foundation | None |
| R-09 | bug | P1 | settings-ui | planned | roadmap | v0.1.7 — Reliability Foundation | None |
| R-10 | enhancement | P1 | app-launching | planned | roadmap | v0.1.7 — Reliability Foundation | None |
| R-11 | enhancement | P1 | settings-ui, hotkeys | planned | roadmap | v0.1.7 — Reliability Foundation | None |
| R-12 | bug | P1 | settings-ui | planned | roadmap | v0.1.7 — Reliability Foundation | None |
| R-13 | bug | P2 | hotkeys | planned | roadmap | v0.1.7 — Reliability Foundation | None |
| R-14 | enhancement | P0 | updates-release, documentation | planned | roadmap, release-blocker | v0.2.0 — Trusted Public Release | None |
| R-15 | enhancement | P0 | updates-release | blocked | roadmap, release-blocker | v0.2.0 — Trusted Public Release | R-14 |
| R-16 | enhancement | P0 | updates-release | blocked | roadmap, release-blocker | v0.2.0 — Trusted Public Release | R-02, R-04, R-15 |
| R-17 | enhancement | P1 | updates-release | blocked | roadmap | v0.2.0 — Trusted Public Release | R-02 |
| R-18 | enhancement | P0 | settings-ui, accessibility | blocked | roadmap, release-blocker | v0.2.0 — Trusted Public Release | R-08 |
| R-19 | enhancement | P1 | updates-release, documentation | blocked | roadmap | v0.2.0 — Trusted Public Release | R-15 |
| R-20 | documentation | P0 | documentation | planned | roadmap, release-blocker | v0.2.0 — Trusted Public Release | None |
| R-21 | documentation | P1 | documentation, updates-release | blocked | roadmap | v0.2.0 — Trusted Public Release | R-16 |
| R-22 | enhancement | P1 | hotkeys, settings-ui | planned | roadmap | v0.2.x — Daily-use Polish | None |
| R-23 | enhancement | P1 | settings-ui, hotkeys | blocked | roadmap | v0.2.x — Daily-use Polish | R-22 |
| R-24 | enhancement | P2 | hotkeys, settings-ui | blocked | roadmap | v0.2.x — Daily-use Polish | R-07 |
| R-25 | enhancement | P1 | app-launching, settings-ui | planned | roadmap | v0.2.x — Daily-use Polish | None |
| R-26 | bug | P2 | app-launching, settings-ui | blocked | roadmap | v0.2.x — Daily-use Polish | R-10 |
| R-27 | enhancement | P2 | window-management, settings-ui | planned | roadmap | v0.2.x — Daily-use Polish | None |
| R-28 | enhancement | P1 | accessibility, settings-ui | planned | roadmap | v0.2.x — Daily-use Polish | None |
| R-29 | enhancement | P2 | localization, settings-ui | blocked | roadmap | v0.2.x — Daily-use Polish | R-28 |
| R-30 | enhancement | P3 | hotkeys | planned | roadmap, tech-debt | v0.2.x — Daily-use Polish | None |
| R-31 | enhancement | P1 | app-launching, settings-ui | planned | roadmap | v0.3.0 — Faster App Switching | None |
| R-32 | enhancement | P1 | app-launching, accessibility | blocked | roadmap | v0.3.0 — Faster App Switching | R-06, R-31 |
| R-33 | enhancement | P1 | settings-ui | blocked | roadmap | v0.3.0 — Faster App Switching | R-12 |
| R-34 | enhancement | P1 | window-management, accessibility | blocked | roadmap | v0.4.0 — Named Workspaces | R-06 |
| R-35 | enhancement | P1 | window-management, settings-ui | blocked | roadmap | v0.4.0 — Named Workspaces | R-33, R-34 |
| R-36 | enhancement | P1 | window-management, accessibility | blocked | roadmap | v0.4.0 — Named Workspaces | R-35 |
| R-37 | enhancement | P2 | window-management | blocked | roadmap | v0.5.0 — Context Restoration | R-35 |
| R-38 | enhancement | P2 | window-management, accessibility | blocked | roadmap | v0.5.0 — Context Restoration | R-36, R-37 |

---

## User Problem and Evidence Matrix

Use commit permalink base:

```text
https://github.com/woosublee/zap/blob/59498cdcb46fe1b42ea25967ee7986c2618b41a1/
```

| ID | Canonical User problem | Required evidence |
|---|---|---|
| R-01 | 제품 backlog와 release 조건이 PR, spec, release note에 흩어져 앞으로 할 일과 완료된 일을 구분하기 어렵다. | GitHub Issues와 milestones가 비어 있는 현재 repository 링크, PR #1~#8 |
| R-02 | PR과 main push에서 자동 검증하지 않아 release를 시작한 뒤에야 빌드·테스트 실패를 발견할 수 있다. | `.github/workflows/release.yml:8-23`, `Tests/ScriptTests/generate-sparkle-appcast-tests.sh:1-138` |
| R-03 | 핵심 UI·권한·history 테스트가 실제 동작 대신 source 문자열에 결합되어 P0 reliability 수정을 충분히 보호하지 못한다. | `Tests/ZapAppTests/ShortcutRecorderViewTests.swift:11-92`, `Tests/ZapAppTests/SettingsWindowManagementUITests.swift:22-355` |
| R-04 | version과 build metadata가 여러 파일에 분산되고 이전 release보다 증가했는지 검증하지 않아 Sparkle update가 누락될 수 있다. | `Makefile:4-6`, `Info.plist:13-16`, `.github/workflows/release.yml:35-61` |
| R-05 | 홀수 크기 display에서 half/corner layout이 1px gap을 만들거나 clamp 후 frame이 visible bounds 밖에 남을 수 있다. | `Sources/ZapCore/WindowPositionCalculator.swift:93-164`, `Sources/ZapCore/WindowPositionCalculator.swift:226-253`, PR #5 review threads |
| R-06 | Undo/Redo가 앱 단위이고 성공 전에 stack을 변경해 같은 앱의 다른 창을 이동하거나 실패 시 history를 잃을 수 있다. | `Sources/ZapCore/WindowHistory.swift:13-66`, `Sources/ZapApp/Services/WindowManagementService.swift:159-230` |
| R-07 | shortcut recorder를 여는 동안 기존 Zap hotkey가 등록되어 녹화 입력이 앱 실행이나 창 이동을 유발할 수 있다. | `Sources/ZapApp/Views/ShortcutRecorderView.swift:47-127`, `Sources/ZapApp/Views/SettingsView.swift:72-106` |
| R-08 | Accessibility 권한과 user opt-in이 없어도 Window Management hotkey를 점유해 사용할 수 없는 키가 다른 앱을 방해한다. | `Sources/ZapApp/ViewModels/WindowManagementModel.swift:59-61`, `Sources/ZapApp/ViewModels/ZapAppModel.swift:390-407` |
| R-09 | Launch at Login switch가 저장된 Boolean만 보여 등록 실패나 외부 변경 후 실제 macOS 상태와 다를 수 있다. | `Sources/ZapApp/ViewModels/ZapAppModel.swift:495-501`, `Sources/ZapApp/Services/LoginItemService.swift:3-14` |
| R-10 | Dock hotkey마다 main actor에서 plist와 app bundle metadata를 다시 읽고 menu label과 activation이 다른 snapshot을 사용할 수 있다. | `Sources/ZapApp/Services/DockItemProvider.swift:15-43`, `Sources/ZapApp/ViewModels/ZapAppModel.swift:331-337` |
| R-11 | 실패가 beep, raw enum, OSStatus 또는 silent no-op으로 끝나 사용자가 지원 요청에 필요한 원인을 알 수 없다. | `Sources/ZapApp/Services/GlobalHotKeyService.swift:386-405`, `Sources/ZapApp/ViewModels/WindowManagementModel.swift:64-73` |
| R-12 | 일부 설정 JSON이 손상되면 정상 항목까지 빈 목록이나 default로 조용히 돌아갈 수 있다. | `Sources/ZapApp/ViewModels/ZapAppModel.swift:509-561`, `Sources/ZapApp/ViewModels/WindowManagementModel.swift:155-166` |
| R-13 | sleep, wake, system clock 변경 후 pause timer와 실제 registration 상태가 어긋날 수 있다. | `Sources/ZapApp/ViewModels/ZapAppModel.swift:188-263`, `Sources/ZapApp/ViewModels/ZapAppModel.swift:419-432` |
| R-14 | 공식 artifact가 사실상 arm64지만 다운로드·appcast에서 지원 architecture와 minimum OS를 명확히 알 수 없다. | `.github/workflows/release.yml:21-23`, `scripts/generate-sparkle-appcast.sh:108-130`, `README.md:195-202` |
| R-15 | self-signed, non-notarized DMG가 Gatekeeper 우회를 요구해 Accessibility 앱에 필요한 소비자 신뢰를 훼손한다. | `.github/workflows/release.yml:1-6`, `Makefile:102-129`, `README.md:169-176` |
| R-16 | feature branch release, concurrent release, partial asset upload가 latest Sparkle feed를 오염시킬 수 있다. | `.github/workflows/release.yml:8-17`, `.github/workflows/release.yml:128-176` |
| R-17 | Sparkle release tool archive를 checksum 검증 없이 실행하고 release artifact provenance를 게시하지 않는다. | `Makefile:177-190`, `scripts/generate-sparkle-appcast.sh:57-75` |
| R-18 | 메뉴바 앱을 처음 실행해도 onboarding 없이 hotkey가 등록되어 사용자는 mapping, 권한, 첫 성공 경로를 알기 어렵다. | `Sources/ZapApp/ZapApp.swift:11-32`, `Sources/ZapApp/ViewModels/ZapAppModel.swift:205-214` |
| R-19 | 소비자용 download/install/uninstall flow와 Applications drag target이 없어 DMG에서 직접 실행하거나 잔여 설정을 남길 수 있다. | `Makefile:212-247`, `Makefile:267-283`, `README.md:125-202` |
| R-20 | Accessibility·global hotkey 권한을 요청하지만 privacy, support, security, license, third-party notice가 독립 문서로 존재하지 않는다. | `README.md:117-123`, `Sources/ZapApp/Views/AboutView.swift:19-31` |
| R-21 | release note와 README가 v0.1.6의 Pause, per-app disable, active-app toggle과 compatibility를 충분히 설명하지 않는다. | `README.md:16-20`, `README.md:76-115`, release v0.1.6 |
| R-22 | pause와 app-disabled 상태가 재실행 후에도 유지되지만 남은 시간과 현재 상태가 icon/menu에서 충분히 보이지 않는다. | `Sources/ZapApp/Views/MenuBarView.swift:37-74`, `Sources/ZapApp/ZapApp.swift:53-64` |
| R-23 | disabled app 목록을 저장하지만 Settings에서 전체 목록을 조회하거나 일괄 복구할 수 없다. | `Sources/ZapApp/ViewModels/ZapAppModel.swift:265-274`, `Sources/ZapApp/ViewModels/ZapAppModel.swift:564-572` |
| R-24 | 게임·IDE·원격 데스크톱 진입 전 menu를 열지 않고 전체 Zap hotkey를 pause/resume할 방법이 없다. | `Sources/ZapApp/Views/MenuBarView.swift:37-67`, active-app toggle design의 global pause shortcut 비목표 |
| R-25 | Automatic Dock shortcuts를 명시적으로 Off할 수 없고 modifier를 모두 해제해도 재실행 후 Option default가 복원된다. | `Sources/ZapApp/ViewModels/ZapAppModel.swift:280-285`, `Sources/ZapApp/ViewModels/ZapAppModel.swift:547-554` |
| R-26 | Manual app이 이동·재설치되거나 같은 앱이 중복 추가되면 shortcut이 beep로 실패하고 복구 경로가 없다. | `Sources/ZapApp/Models/ManualShortcut.swift:4-12`, `Sources/ZapApp/Services/AppLauncher.swift:36-49` |
| R-27 | `Fullscreen`, `Next Third`, 반복 Half/Corner 동작의 이름과 실제 결과가 달라 사용자가 기능을 예측하기 어렵다. | `Sources/ZapCore/WindowAction.swift:32-67`, `Sources/ZapCore/WindowPositionCalculator.swift:105-223` |
| R-28 | 고정 크기 Settings, recorder pulse, 부족한 accessibility semantics 때문에 VoiceOver·큰 글꼴·Reduce Motion 사용자가 설정을 완료하기 어렵다. | `Sources/ZapApp/Views/SettingsView.swift:40-71`, `Sources/ZapApp/Views/ShortcutRecorderView.swift:50-100` |
| R-29 | key display가 US QWERTY와 Korean mapping에 하드코딩되어 AZERTY, JIS, Dvorak 등에서 실제 key와 표시가 다를 수 있다. | `Sources/ZapApp/Models/ShortcutKeyDisplay.swift:4-82`, `Package.swift:19-31` |
| R-30 | Carbon hotkey signature가 이전 제품명 `SNAP`을 계속 사용해 binary와 diagnostics의 제품명이 완전히 일치하지 않는다. | `Sources/ZapApp/Services/GlobalHotKeyService.swift:295-299` |
| R-31 | 이미 frontmost인 앱에 같은 shortcut을 반복해도 activate만 다시 호출되어 직전 작업으로 빠르게 돌아갈 수 없다. | `Sources/ZapApp/Services/AppLauncher.swift:36-49`, rcmd changelog |
| R-32 | 한 앱의 여러 창을 쓰는 사용자는 Zap으로 앱을 연 뒤 별도 shortcut으로 원하는 창을 다시 찾아야 한다. | `Sources/ZapApp/Services/AppLauncher.swift:36-49`, `Sources/ZapApp/Services/AccessibilityWindowService.swift:68-72`, AltTab features |
| R-33 | Mac 교체나 재설치 시 여러 UserDefaults key에 흩어진 shortcut과 설정을 다시 만들어야 한다. | `Sources/ZapApp/ViewModels/ZapAppModel.swift:504-572`, `Sources/ZapApp/ViewModels/WindowManagementModel.swift:146-192` |
| R-34 | 현재 AX service가 frontmost window 하나만 다뤄 여러 앱·창 workspace를 안전하게 저장할 수 없다. | `Sources/ZapApp/Services/AccessibilityWindowService.swift:68-72`, `Sources/ZapApp/Services/AccessibilityWindowService.swift:193-203` |
| R-35 | Coding, Writing, Meeting 등 반복하는 앱·창 배치를 이름 붙여 저장할 수 없다. | `Sources/ZapApp/Services/AccessibilityWindowService.swift:68-72`, Rectangle Pro layouts |
| R-36 | 여러 앱·창 배치를 한 번에 복원하고 partial failure를 이해하거나 전체 작업을 Undo할 수 없다. | `Sources/ZapApp/Services/WindowManagementService.swift:70-230`, `Sources/ZapCore/WindowHistory.swift:13-66` |
| R-37 | 노트북 단독, 집, 사무실 display 구성을 구분해 올바른 workspace preset을 선택할 모델이 없다. | `Sources/ZapCore/WindowPositionCalculator.swift:50-86`, `Sources/ZapApp/Services/AccessibilityWindowService.swift:273-295` |
| R-38 | external display 연결·해제나 wake 뒤 무너진 창 배치를 사용자가 매번 수동 복원해야 한다. | Moom custom actions, Rectangle Pro layouts, R-35/R-36 |

When creating bodies, turn every local evidence entry into a commit permalink and include the cited external product URL from the design research where named.

---

### Task 1: Preflight repository identity, authentication, and existing roadmap markers

**Files:**
- Read: `/Users/woosublee/Documents/dev/zap/docs/superpowers/specs/2026-07-27-zap-product-roadmap-design.md`
- Create temporary: `/tmp/zap-roadmap-sync/preflight.json`
- Create temporary: `/tmp/zap-roadmap-sync/issue-map.json`

**Interfaces:**
- Consumes: authenticated `gh`, repository `woosublee/zap`
- Produces: verified repository identity and existing marker map used by every later task

- [ ] **Step 1: Reconfirm external-change authorization and GitHub authentication**

Run:

```bash
cd /Users/woosublee/Documents/dev/zap
gh auth status
gh repo view woosublee/zap --json nameWithOwner,isPrivate,defaultBranchRef,url
```

Expected:

- authenticated account can write to `woosublee/zap`;
- `nameWithOwner` is exactly `woosublee/zap`;
- default branch is `main`.

Stop without changing GitHub if any value differs.

- [ ] **Step 2: Create the isolated temporary working directory**

Run:

```bash
rm -rf /tmp/zap-roadmap-sync
mkdir -p /tmp/zap-roadmap-sync/bodies
printf '{}\n' > /tmp/zap-roadmap-sync/issue-map.json
```

Expected: the directory contains `bodies/` and an empty JSON map.

- [ ] **Step 3: Snapshot current labels, milestones, and Issues**

Run:

```bash
gh api 'repos/woosublee/zap/labels?per_page=100' --paginate --slurp \
  > /tmp/zap-roadmap-sync/labels.json
gh api 'repos/woosublee/zap/milestones?state=all&per_page=100' --paginate --slurp \
  > /tmp/zap-roadmap-sync/milestones.json
gh api 'repos/woosublee/zap/issues?state=all&per_page=100' --paginate --slurp \
  > /tmp/zap-roadmap-sync/issues.json
```

Expected: all three files contain valid arrays-of-pages JSON. Marker and invariant scripts flatten one level before inspecting entries.

- [ ] **Step 4: Build and validate the existing marker map**

Use Python to read every non-PR Issue body, extract `<!-- roadmap-id:... -->`, and write `/tmp/zap-roadmap-sync/issue-map.json`.

Validation rules:

- allowed IDs are `R-01` through `R-38` and `TRACKING`;
- duplicate markers are fatal;
- a marker with an unknown ID is fatal;
- existing matching Issues may be open or closed and must be reused;
- existing PRs are ignored even though the REST Issues endpoint returns them.

Expected for the current repository: an empty map because no Issues exist.

- [ ] **Step 5: Verify the design document before external writes**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
import re
p = Path('/Users/woosublee/Documents/dev/zap/docs/superpowers/specs/2026-07-27-zap-product-roadmap-design.md')
s = p.read_text()
ids = re.findall(r'^#### (R-\d{2})', s, re.M)
assert ids == [f'R-{i:02d}' for i in range(1, 39)]
assert len(re.findall(r'^### .*Exit Gate$', s, re.M)) == 7
assert not re.findall(r'\b(?:TBD|TODO|FIXME)\b', s)
print('design preflight passed')
PY
```

Expected: `design preflight passed`.

---

### Task 2: Upsert the canonical labels

**Files:**
- Read: `/tmp/zap-roadmap-sync/labels.json`
- Modify external: GitHub repository labels

**Interfaces:**
- Consumes: Canonical Label Definitions
- Produces: every label required by the metadata matrix

- [ ] **Step 1: Re-read labels immediately before the first write**

Run:

```bash
gh label list --repo woosublee/zap --limit 100
```

Expected: existing default labels are visible.

- [ ] **Step 2: Upsert priority, area, status, and flag labels**

For each label in Canonical Label Definitions, run the exact equivalent of:

```bash
gh label create 'priority:P0' \
  --repo woosublee/zap \
  --color B60205 \
  --description 'GA 또는 release를 차단하는 최우선 작업' \
  --force
```

Repeat with the exact name, color, and description from the table. Do not modify existing `bug`, `documentation`, or `enhancement` unless one is missing; if missing, create it with GitHub’s standard default color and description.

- [ ] **Step 3: Verify the exact label set**

Run:

```bash
gh label list --repo woosublee/zap --limit 100 --json name,color,description \
  > /tmp/zap-roadmap-sync/labels-after.json
```

Use Python to assert that all 21 canonical labels exist once with matching colors and descriptions and that `bug`, `documentation`, `enhancement` exist.

Expected: zero missing or duplicate canonical labels.

---

### Task 3: Upsert the seven milestones

**Files:**
- Read: `/tmp/zap-roadmap-sync/milestones.json`
- Modify external: GitHub milestones

**Interfaces:**
- Consumes: Canonical Milestones
- Produces: title-to-milestone-number mapping for Issue creation

- [ ] **Step 1: Fetch all open and closed milestones immediately before writes**

Run:

```bash
gh api 'repos/woosublee/zap/milestones?state=all&per_page=100' --paginate --slurp \
  > /tmp/zap-roadmap-sync/milestones-before-apply.json
```

Flatten the arrays-of-pages before exact-title matching.

- [ ] **Step 2: Upsert milestones by exact title**

For each canonical milestone:

1. search all states for exact title;
2. fail on duplicates;
3. if missing, `POST /repos/woosublee/zap/milestones` with `title`, `description`, `state: open`;
4. if present, `PATCH /repos/woosublee/zap/milestones/{number}` with canonical description, `state: open`, and `due_on: null`.

Use a Python standard-library script calling `gh api`; do not rely on title substring matching.

- [ ] **Step 3: Persist milestone number mapping**

Write `/tmp/zap-roadmap-sync/milestone-map.json` as:

```json
{
  "Roadmap & Engineering Baseline": 1,
  "v0.1.7 — Reliability Foundation": 2,
  "v0.2.0 — Trusted Public Release": 3,
  "v0.2.x — Daily-use Polish": 4,
  "v0.3.0 — Faster App Switching": 5,
  "v0.4.0 — Named Workspaces": 6,
  "v0.5.0 — Context Restoration": 7
}
```

The numbers above illustrate the required shape only; store the actual API-returned numbers.

- [ ] **Step 4: Verify milestone invariants**

Assert:

- exactly seven exact-title canonical milestones exist;
- each is open;
- each description matches the table;
- each has `due_on == null`;
- duplicate exact titles do not exist.

---

### Task 4: Create canonical body files and upsert R-01 through R-04

**Files:**
- Create temporary: `/tmp/zap-roadmap-sync/bodies/R-01.md` through `R-04.md`
- Modify external: baseline GitHub Issues

**Interfaces:**
- Consumes: design spec sections R-01~R-04, metadata matrix, user-problem/evidence matrix, milestone map, issue map
- Produces: Issue map entries R-01~R-04 for downstream dependencies

- [ ] **Step 1: Build each canonical body**

For each R-ID, write the sections in this exact order:

1. `<!-- roadmap-id:R-XX -->`, replacing `R-XX` with the current ID;
2. `## User problem` with the exact sentence from the User Problem and Evidence Matrix row;
3. `## Product value` with the exact `User value` text from the matching design-spec section;
4. `## Scope` with the exact spec bullets, or the literal `None` when the section has no Scope;
5. `## Acceptance criteria` with every exact spec bullet;
6. `## Dependencies` with one Markdown link per dependency resolved from `issue-map.json`, or `None`;
7. `## External prerequisites` with the exact spec bullets, or `None`;
8. `## Non-goals` with the exact spec text, or `None`;
9. `## Evidence` with at least one commit permalink or GitHub repository, PR, release, or cited external-product URL from the evidence matrix;
10. `## Milestone exit-gate impact` with the exact gate bullet this Issue advances, or `Non-gating`.

For R-01 the marker is exactly `<!-- roadmap-id:R-01 -->`; apply the same deterministic substitution for R-02 through R-38.

- [ ] **Step 2: Validate the four body files locally**

Assert for each body:

- exactly one matching marker;
- all nine `##` headings exist;
- no unfinished template text or empty required section remains;
- Evidence contains an `https://` link;
- dependency IDs, if any, are rendered as GitHub Issue links.

- [ ] **Step 3: Upsert Issues sequentially**

For R-01 through R-04:

1. refresh current marker map;
2. resolve the canonical milestone number;
3. build the exact labels array from the metadata matrix;
4. if marker is absent, `POST /repos/woosublee/zap/issues`;
5. if marker exists once, `PATCH /repos/woosublee/zap/issues/{number}`;
6. write returned number and URL to `issue-map.json` before moving to the next R-ID.

Canonical titles are the backticked titles in the design spec, without the backticks.

- [ ] **Step 4: Verify the baseline slice**

Expected:

- R-01 and R-02 have `status:ready`;
- R-03 and R-04 have `status:blocked`;
- R-02 and R-03 have `release-blocker`;
- all four have `roadmap`;
- R-03 and R-04 dependency links point to the actual R-02 Issue.

---

### Task 5: Upsert v0.1.7 R-05 through R-13

**Files:**
- Create temporary: `/tmp/zap-roadmap-sync/bodies/R-05.md` through `R-13.md`
- Modify external: v0.1.7 GitHub Issues

**Interfaces:**
- Consumes: issue map entries R-02/R-03, spec sections R-05~R-13, metadata matrix, user-problem/evidence matrix
- Produces: issue map entries R-05~R-13

- [ ] **Step 1: Build and validate nine canonical bodies**

Each R-05~R-13 body must contain, in order, its exact marker, User problem, Product value, Scope, Acceptance criteria, Dependencies, External prerequisites, Non-goals, Evidence, and Milestone exit-gate impact. Use literal `None` for absent fields, require at least one `https://` Evidence link, and fail validation for an empty section or dependency that is not an actual Issue link.

- [ ] **Step 2: Upsert R-05 through R-13 sequentially**

For each ID, refresh markers, resolve its milestone and dependency URLs, build the exact labels array, POST only when the marker is absent, otherwise PATCH the single existing Issue, then persist its returned number and URL before continuing.

- [ ] **Step 3: Verify the reliability slice**

Expected:

- nine Issues are assigned to `v0.1.7 — Reliability Foundation`;
- R-05 and R-06 are blocked by linked baseline Issues;
- R-07~R-13 are planned because their milestone is not active and they have no unresolved explicit dependencies;
- R-06 and R-08 carry `release-blocker`;
- no Issue has more than two area labels.

---

### Task 6: Upsert v0.2.0 R-14 through R-21

**Files:**
- Create temporary: `/tmp/zap-roadmap-sync/bodies/R-14.md` through `R-21.md`
- Modify external: v0.2.0 GitHub Issues

**Interfaces:**
- Consumes: issue map entries R-02, R-04, R-08, R-14, R-15, R-16
- Produces: issue map entries R-14~R-21

- [ ] **Step 1: Build and validate eight canonical bodies**

Each R-14~R-21 body must contain its exact marker and all nine required headings, use `None` for absent fields, include at least one Evidence URL, and resolve every R-ID dependency to an actual Issue link. R-15 must place Apple Developer Program membership, Developer ID Application certificate, and App Store Connect notarization credential under External prerequisites, not Dependencies.

- [ ] **Step 2: Upsert R-14 through R-21 sequentially**

For each ID, refresh markers, resolve its canonical milestone number and dependency URLs, POST only when absent, otherwise PATCH the single marker owner, persist its number and URL, and apply the exact metadata-matrix labels.

- [ ] **Step 3: Verify the GA slice**

Expected:

- eight Issues are assigned to `v0.2.0 — Trusted Public Release`;
- R-14, R-15, R-16, R-18, R-20 carry `release-blocker`;
- R-15 depends only on R-14;
- R-16 links R-02, R-04, R-15;
- R-18 links R-08;
- R-21 links R-16;
- external credentials are plain prerequisite bullets and not Issue links.

---

### Task 7: Upsert v0.2.x R-22 through R-30

**Files:**
- Create temporary: `/tmp/zap-roadmap-sync/bodies/R-22.md` through `R-30.md`
- Modify external: v0.2.x GitHub Issues

**Interfaces:**
- Consumes: issue map entries R-07, R-10, R-22, R-28
- Produces: issue map entries R-22~R-30

- [ ] **Step 1: Build and validate nine canonical bodies**

Each R-22~R-30 body must contain its exact marker and all nine required headings, use `None` for absent fields, include at least one Evidence URL, and resolve dependencies through `issue-map.json`. Preserve these deterministic acceptance criteria from the spec:

- R-24 pause state transitions;
- R-28 820×640 default and 720×560 minimum;
- R-29 exact US ANSI, Korean 2-set, Japanese JIS, French AZERTY scope;
- R-30 legacy `SNAP` text only as the identifier being removed.

- [ ] **Step 2: Upsert R-22 through R-30 sequentially**

For each ID, refresh markers, resolve milestone and dependency URLs, POST only when absent, otherwise PATCH the single marker owner, persist its number and URL, and normalize title, body, labels, open state, and milestone.

- [ ] **Step 3: Verify the daily-use polish slice**

Expected:

- nine Issues are assigned to `v0.2.x — Daily-use Polish`;
- R-23, R-24, R-26, R-29 are blocked with correct links;
- R-30 has `tech-debt` and does not use product name Snap outside the legacy signature explanation;
- every Issue has one status and at most two area labels.

---

### Task 8: Upsert v0.3.0 through v0.5.0 R-31 through R-38

**Files:**
- Create temporary: `/tmp/zap-roadmap-sync/bodies/R-31.md` through `R-38.md`
- Modify external: future feature GitHub Issues

**Interfaces:**
- Consumes: issue map entries R-06, R-12, R-31, R-33, R-34, R-35, R-36, R-37
- Produces: complete R-01~R-38 issue map

- [ ] **Step 1: Build and validate eight canonical bodies**

Each R-31~R-38 body must contain its exact marker and all nine required headings, use `None` for absent fields, include repository or cited external-product Evidence URLs, and resolve dependencies through `issue-map.json`. Preserve these product contracts:

- R-31 excludes Finder from repeated-action policy;
- R-32 depends on both R-06 and R-31;
- R-33 Merge preserves existing values and adds only missing entries, while Replace atomically replaces the exportable configuration;
- R-34 matching order is session identity → stable AXIdentifier → single eligible candidate;
- R-36 moves only exact/unambiguous matches and commits only successful moves to global undo;
- R-38 uses a 2-second debounce and cancels on user-originated AX move/resize during that window.

- [ ] **Step 2: Upsert R-31 through R-38 sequentially**

For each ID, refresh markers, resolve milestone and dependency URLs, POST only when absent, otherwise PATCH the single marker owner, persist its number and URL, and normalize title, body, labels, open state, and milestone.

- [ ] **Step 3: Verify future feature slices**

Expected counts:

- v0.3.0: 3 Issues;
- v0.4.0: 3 Issues;
- v0.5.0: 2 Issues;
- R-32 links R-06 and R-31;
- R-35 links R-33 and R-34;
- R-38 links R-36 and R-37.

---

### Task 9: Normalize all Issue bodies and verify the dependency graph

**Files:**
- Read temporary: all 38 body files and `issue-map.json`
- Modify external: all 38 Issues if canonical bodies changed during mapping
- Create temporary: `/tmp/zap-roadmap-sync/dependency-report.json`

**Interfaces:**
- Consumes: complete issue map
- Produces: fully linked, cycle-free dependency graph

- [ ] **Step 1: Rebuild every body using the final issue map**

Even if an Issue was already created, regenerate all 38 body files. For each dependency, load the number and URL from `issue-map.json` and render it with this Python expression:

```python
line = f"- [{dependency_id} — #{dependency['number']}]({dependency['url']})"
```

No raw dependency R-ID without its actual GitHub Issue link may remain in the final Dependencies section.

- [ ] **Step 2: Patch all 38 Issues to the final canonical body and metadata**

For every Issue, PATCH exact title, body, labels, open state, and milestone number. This makes reruns convergent and removes accidental label drift.

- [ ] **Step 3: Validate graph invariants**

Use Python to assert:

- every dependency points to an earlier R-ID;
- no cycles exist;
- every linked Issue exists in `issue-map.json`;
- External prerequisites contain no GitHub Issue link unless independently listed in Dependencies;
- R-01~R-38 each appear exactly once.

- [ ] **Step 4: Write the dependency report**

`dependency-report.json` must contain all 38 IDs, dependency IDs, actual Issue numbers, and a `cycle_free: true` field.

---

### Task 10: Create or update the Zap Product Roadmap tracking Issue

**Files:**
- Create temporary: `/tmp/zap-roadmap-sync/tracking.md`
- Modify external: one tracking Issue

**Interfaces:**
- Consumes: complete issue and milestone maps, seven exit gates from the spec
- Produces: public navigation entry for the whole roadmap

- [ ] **Step 1: Build the tracking body**

Use marker:

```markdown
<!-- roadmap-id:TRACKING -->
```

The body must include:

1. product definition;
2. non-goals;
3. milestone order;
4. all seven exact exit gates;
5. milestone sections with `- [ ] R-XX — #number — title` checklist entries;
6. current active milestone `Roadmap & Engineering Baseline`;
7. current ready Issues R-01 and R-02;
8. note that due dates are intentionally omitted;
9. link to the committed design spec path in the repository.

- [ ] **Step 2: Validate tracking body locally**

Assert:

- marker occurs once;
- exactly 38 unique R-ID checklist items exist;
- exactly seven `Exit Gate` headings exist;
- every checklist URL matches `issue-map.json`;
- no placeholder or missing Issue number exists.

- [ ] **Step 3: Upsert the tracking Issue**

Canonical title:

```text
Zap Product Roadmap
```

Canonical labels:

- `enhancement`
- `roadmap`
- `priority:P1`
- `area:documentation`
- `status:in-progress`

Do not assign the tracking Issue to a release milestone. Create if marker is absent; otherwise patch the existing marker owner. Store its number and URL under `TRACKING` in `issue-map.json`.

---

### Task 11: Run full GitHub roadmap verification

**Files:**
- Create temporary: `/tmp/zap-roadmap-sync/verification.json`
- Verify external: labels, milestones, 38 Issues, tracking Issue

**Interfaces:**
- Consumes: canonical definitions and final maps
- Produces: evidence that the rollout is complete and idempotent

- [ ] **Step 1: Fetch fresh authoritative state**

Run fresh API queries for labels, all-state milestones, all-state Issues, and the tracking Issue. Do not verify against the earlier preflight snapshots.

- [ ] **Step 2: Verify label invariants**

Assert:

- all canonical labels exist once;
- colors and descriptions match;
- `bug`, `documentation`, `enhancement` exist.

- [ ] **Step 3: Verify milestone invariants**

Assert:

- exactly seven canonical titles exist once;
- all are open;
- all descriptions match;
- all have no due date.

- [ ] **Step 4: Verify Issue invariants**

Assert:

- exactly 38 Issues have `roadmap-id:R-01` through `R-38`;
- no marker is duplicated;
- each Issue title, type, priority, areas, status, flags, milestone matches the metadata matrix;
- every body has all required headings and at least one Evidence URL;
- every R-ID dependency is an actual Issue link;
- R-01 and R-02 are the only initial `status:ready` roadmap Issues;
- P0 and `release-blocker` assignments match the matrix.

- [ ] **Step 5: Verify tracking invariants**

Assert:

- exactly one `TRACKING` marker exists;
- title is `Zap Product Roadmap`;
- body lists 38 unique Issue links and seven exit gates;
- active milestone and ready Issues are correct.

- [ ] **Step 6: Prove idempotence with a dry rerun**

Repeat marker discovery and canonical comparison without writes. Expected result:

```text
labels_to_create=0
milestones_to_create=0
issues_to_create=0
issues_to_update=0
tracking_to_create=0
tracking_to_update=0
```

- [ ] **Step 7: Report the public links**

Return:

- tracking Issue URL;
- milestone URLs;
- R-01 and R-02 URLs;
- total counts;
- verification result;
- any skipped action or mismatch, without claiming completion if any invariant failed.

---

## Requirement Coverage Matrix

| Design requirement | Plan coverage |
|---|---|
| 7 exact milestones, no due dates | Tasks 3 and 11 |
| 38 sequential Issues | Tasks 4–8 and 11 |
| Stable marker and duplicate prevention | Tasks 1, 4–10 |
| Canonical type/priority/area/status/flags | Metadata matrix, Tasks 4–9, 11 |
| R-ID dependency links | Tasks 4–9 |
| External prerequisites separated | R-15 rule in Task 6; Task 9 validation |
| Full Issue body template | Tasks 4–9 body contract |
| Evidence on every Issue | User Problem and Evidence Matrix; Tasks 4–9 |
| Tracking Issue with 38 checklists and seven exit gates | Task 10 |
| R-01/R-02 first ready Issues | Metadata matrix; Tasks 4 and 11 |
| No GitHub Project | Global Constraints |
| Re-run safety | Marker map, exact-title upserts, Task 11 dry rerun |
| No source-code changes | Global Constraints and temporary-file map |

### Critical Resources for Execution

- `/Users/woosublee/Documents/dev/zap/docs/superpowers/specs/2026-07-27-zap-product-roadmap-design.md`
- `/tmp/zap-roadmap-sync/issue-map.json`
- `https://github.com/woosublee/zap/issues`
- `https://github.com/woosublee/zap/milestones`
- `https://github.com/woosublee/zap/labels`
