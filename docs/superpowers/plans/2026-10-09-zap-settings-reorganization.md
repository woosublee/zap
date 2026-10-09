# Zap 설정 창 재구성 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 설정 창을 General · Apps · Windows 3개 메뉴로 재구성하고, 화면 안의 중복·잘림·경고 반복을 정리하며, App Store 빌드에서 업데이트 UI를 숨길 수 있는 판단 지점을 만든다.

**Architecture:** 표현 계층(SwiftUI 뷰)과 그 주변의 작은 순수 로직(초기 화면 결정, 오류 메시지 정리, keycap 라벨 변환, 배포 채널 판단)만 바꾼다. `ZapAppModel`·`WindowManagementModel`의 API, 저장 포맷, 단축키 등록 동작은 바꾸지 않는다. 공용 UI 부품(`SettingsCard` accessory 슬롯, `SettingsIssueBanner`, keycap 라벨 변환)을 먼저 만들고, 그 위에서 화면을 하나씩 바꾼다.

**Tech Stack:** Swift 5.10, SwiftUI, AppKit, XCTest, macOS 13+

**Spec:** `docs/superpowers/specs/2026-10-09-zap-settings-reorganization-design.md`

## Global Constraints

- 제품명은 항상 `Zap`을 사용하고 옛 이름(Snap)은 사용하지 않는다.
- 지원 하한은 macOS 13이며 `Package.swift`에 새 dependency를 추가하지 않는다.
- 설정 창 크기는 820×640, 사이드바 폭은 216을 유지한다.
- `ZapAppModel`, `WindowManagementModel`, `WindowShortcutRowView`, `ManualShortcutRow`, `ShortcutKeyDisplay`의 동작과 저장 값은 바꾸지 않는다.
- 테스트 실행은 항상 `swift test --scratch-path "$HOME/Library/Caches/zap-build"`로 한다. 저장소가 iCloud 동기화 폴더(`~/Documents`) 안에 있어서, 기본 `.build` 경로에서는 PermissionFlow 번들 codesign이 "resource fork, Finder information, or similar detritus not allowed"로 실패한다.
- 이 저장소의 뷰 테스트는 소스 문자열 단언 방식(`String(contentsOf:)` + `contains`)이다. 뷰는 이 방식을 따르고, 순수 로직은 `@testable import ZapApp`로 실제 값을 검증한다.
- 각 커밋 메시지 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`를 붙인다.
- 작업 브랜치: `feature/settings-reorganization` (스펙 커밋 `1e9744c` 위).

## Review Focus

- 이전 빌드나 손상된 값이 `settings_last_mode`에 남아 있는 경우(예: `"automatic"`, `"about"`, `""`): 예외 없이 General로 열려야 한다. → Task 3 `testInitialModeFallsBackToGeneralForUnknownStoredValue`
- 같은 오류 문자열이 `registrationError`와 `shortcutRegistrationError` 양쪽에서 동시에 올라오는 경우: 배너에 한 번만 보여야 한다. → Task 2 `testUniqueMessagesDropsDuplicatesNilAndEmpty`
- 오류 값이 `nil`이 아니라 빈 문자열(`""`)인 경우: 빈 배너가 그려지면 안 된다. → Task 2 같은 테스트
- 기호로 바꾸지 않는 여러 글자 키(`Space`, `F12`, 한글 입력 소스의 `ㅐ`): 원래 라벨 그대로 한 줄로 보여야 한다. → Task 1 `testDisplayKeepsOtherLabelsUnchanged`
- Finder 단축키를 끈 상태: Finder 행은 흐려지지만 스위치는 흐려지지 않고 다시 켤 수 있어야 한다. → Task 5 `testFinderRowDimsOnlyKeycapAndTitleNotSwitch`

---

## File Map

### Create
- `Sources/ZapApp/Models/AppDistribution.swift`: 배포 채널(`direct`/`appStore`)과 인앱 업데이트 지원 여부.
- `Tests/ZapAppTests/SettingsNavigationTests.swift`: 초기 화면 결정과 마지막 화면 저장.
- `Tests/ZapAppTests/SettingsIssueBannerTests.swift`: 배너 메시지 정리.
- `Tests/ZapAppTests/ShortcutKeycapLabelTests.swift`: keycap 기호 변환.
- `Tests/ZapAppTests/AppDistributionTests.swift`: 배포 채널 판단.

### Modify
- `Sources/ZapApp/Views/ZapDesignSystem.swift`: `ShortcutKeycapLabel`, keycap 줄바꿈 방지, `SettingsCard` accessory 슬롯, `SettingsIssueBanner`.
- `Sources/ZapApp/Views/SettingsView.swift`: `SettingsMode` 축소, 내비게이션 상태 저장, 사이드바, General, Apps.
- `Sources/ZapApp/Services/SettingsWindowPresenter.swift`: 초기 화면 결정.
- `Sources/ZapApp/Views/WindowManagementSettingsView.swift`: 카드 제목과 accessory, 단일 열 목록, 배너.
- `Sources/ZapApp/Views/MenuBarView.swift`, `Sources/ZapApp/ZapApp.swift`: `About Zap` 항목, 업데이트 항목 조건부 표시.
- `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`, `Tests/ZapAppTests/SettingsShortcutControlsUITests.swift`, `Tests/ZapAppTests/MenuBarViewTests.swift`: 바뀐 구조에 맞게 단언을 갱신한다.
- `README.md`, `assets/screenshots/`: 스크린샷 교체.

---

### Task 1: Keycap 라벨 기호 변환과 줄바꿈 방지

**Files:**
- Modify: `Sources/ZapApp/Views/ZapDesignSystem.swift` (`ShortcutKeycapView`, 약 66-100행)
- Test: `Tests/ZapAppTests/ShortcutKeycapLabelTests.swift` (새 파일)

**Interfaces:**
- Consumes: 없음
- Produces: `enum ShortcutKeycapLabel { static func display(_ label: String) -> String }`

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/ZapAppTests/ShortcutKeycapLabelTests.swift`:

```swift
import XCTest
@testable import ZapApp

final class ShortcutKeycapLabelTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testDisplayReplacesMultiCharacterKeyNamesWithSymbols() {
        XCTAssertEqual(ShortcutKeycapLabel.display("Return"), "↩")
        XCTAssertEqual(ShortcutKeycapLabel.display("Tab"), "⇥")
        XCTAssertEqual(ShortcutKeycapLabel.display("Delete"), "⌫")
        XCTAssertEqual(ShortcutKeycapLabel.display("Esc"), "⎋")
    }

    func testDisplayKeepsOtherLabelsUnchanged() {
        XCTAssertEqual(ShortcutKeycapLabel.display("Space"), "Space")
        XCTAssertEqual(ShortcutKeycapLabel.display("F12"), "F12")
        XCTAssertEqual(ShortcutKeycapLabel.display("ㅐ"), "ㅐ")
        XCTAssertEqual(ShortcutKeycapLabel.display("⌘"), "⌘")
        XCTAssertEqual(ShortcutKeycapLabel.display("Not set"), "Not set")
    }

    func testKeycapViewRendersDisplayLabelOnOneLineAndKeepsOriginalAccessibilityLabel() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/ZapDesignSystem.swift"))

        XCTAssertTrue(source.contains("Text(displayLabel)"))
        XCTAssertTrue(source.contains(".lineLimit(1)\n            .fixedSize()"))
        XCTAssertTrue(source.contains(".padding(.horizontal, displayLabel.count > 1 ? 7 : 0)"))
        XCTAssertTrue(source.contains(".accessibilityLabel(label)"))
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build" --filter ShortcutKeycapLabelTests`
Expected: 컴파일 실패, "cannot find 'ShortcutKeycapLabel' in scope"

- [ ] **Step 3: 구현**

`ZapDesignSystem.swift`에서 `struct ShortcutKeycapView` 바로 위에 추가:

```swift
enum ShortcutKeycapLabel {
    static func display(_ label: String) -> String {
        switch label {
        case "Return": "↩"
        case "Tab": "⇥"
        case "Delete": "⌫"
        case "Esc": "⎋"
        default: label
        }
    }
}
```

`ShortcutKeycapView.body`를 아래로 바꾸고, `body` 아래에 `displayLabel`을 추가한다:

```swift
    var body: some View {
        Text(displayLabel)
            .lineLimit(1)
            .fixedSize()
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundStyle)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, displayLabel.count > 1 ? 7 : 0)
            .background(backgroundShape)
            .overlay(borderShape)
            .opacity(isDisabled ? 0.55 : 1)
            .accessibilityLabel(label)
    }

    private var displayLabel: String {
        ShortcutKeycapLabel.display(label)
    }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build" --filter "ShortcutKeycapLabelTests|ZapDesignSystemTests"`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add Sources/ZapApp/Views/ZapDesignSystem.swift Tests/ZapAppTests/ShortcutKeycapLabelTests.swift
git commit -m "feat: show symbol keycaps for multi-letter keys

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: SettingsCard accessory 슬롯과 SettingsIssueBanner

**Files:**
- Modify: `Sources/ZapApp/Views/ZapDesignSystem.swift` (`SettingsCard`, 약 10-38행, 파일 끝에 배너 추가)
- Test: `Tests/ZapAppTests/SettingsIssueBannerTests.swift` (새 파일)

**Interfaces:**
- Consumes: 없음
- Produces:
  - `SettingsCard(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content)`: 기존 호출부와 호환된다(`Accessory == EmptyView`).
  - `SettingsCard(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content, @ViewBuilder accessory: () -> Accessory)`: 호출 형태는 `SettingsCard(title:subtitle:) { content } accessory: { ... }`.
  - `struct SettingsIssueBanner: View { init(messages: [String?]); let messages: [String]; static func uniqueMessages(_ messages: [String?]) -> [String] }`

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/ZapAppTests/SettingsIssueBannerTests.swift`:

```swift
import XCTest
@testable import ZapApp

final class SettingsIssueBannerTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testUniqueMessagesDropsDuplicatesNilAndEmpty() {
        XCTAssertEqual(
            SettingsIssueBanner.uniqueMessages(["Shortcut taken", nil, "", "Shortcut taken", "Window error"]),
            ["Shortcut taken", "Window error"]
        )
    }

    func testBannerWithOnlyNilOrEmptyMessagesHasNothingToShow() {
        XCTAssertEqual(SettingsIssueBanner(messages: [nil, ""]).messages, [])
    }

    func testBannerRendersNothingWhenEmptyAndWarningLabelsOtherwise() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/ZapDesignSystem.swift"))

        XCTAssertTrue(source.contains("struct SettingsIssueBanner: View"))
        XCTAssertTrue(source.contains("if !messages.isEmpty {"))
        XCTAssertTrue(source.contains("Label(message, systemImage: \"exclamationmark.triangle.fill\")"))
    }

    func testSettingsCardSupportsTitleRowAccessory() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/ZapDesignSystem.swift"))

        XCTAssertTrue(source.contains("struct SettingsCard<Accessory: View, Content: View>: View"))
        XCTAssertTrue(source.contains("extension SettingsCard where Accessory == EmptyView"))
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build" --filter SettingsIssueBannerTests`
Expected: 컴파일 실패, "cannot find 'SettingsIssueBanner' in scope"

- [ ] **Step 3: 구현**

`ZapDesignSystem.swift`의 `struct SettingsCard` 전체를 아래로 바꾼다:

```swift
struct SettingsCard<Accessory: View, Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let accessory: Accessory
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.medium) {
            HStack(alignment: .center, spacing: ZapSpacing.medium) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.headline, design: .default, weight: .semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: ZapSpacing.medium)

                accessory
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

extension SettingsCard where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, content: content, accessory: { EmptyView() })
    }
}
```

파일 끝에 추가:

```swift
struct SettingsIssueBanner: View {
    let messages: [String]

    init(messages: [String?]) {
        self.messages = Self.uniqueMessages(messages)
    }

    static func uniqueMessages(_ messages: [String?]) -> [String] {
        var seen = Set<String>()
        return messages
            .compactMap { $0 }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    var body: some View {
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(messages, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
            )
        }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인 (기존 호출부 호환 포함)**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build"`
Expected: 전체 PASS. 기존 `SettingsCard(title:) { }` 호출이 모두 컴파일되어야 한다.

- [ ] **Step 5: 커밋**

```bash
git add Sources/ZapApp/Views/ZapDesignSystem.swift Tests/ZapAppTests/SettingsIssueBannerTests.swift
git commit -m "feat: add settings card accessory slot and issue banner

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: SettingsMode 3개로 축소와 마지막 화면 기억

**Files:**
- Modify: `Sources/ZapApp/Views/SettingsView.swift` (`SettingsNavigationState` 6-12행, `body`의 `switch` 51-67행, `sidebarSection` 호출 140-143행, `addManualShortcut` 422행, `enum SettingsMode` 427-455행)
- Modify: `Sources/ZapApp/Services/SettingsWindowPresenter.swift:15-17`
- Test: `Tests/ZapAppTests/SettingsNavigationTests.swift` (새 파일)
- Test: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift` (아래 명시한 테스트 교체)

**Interfaces:**
- Consumes: 없음
- Produces:
  - `enum SettingsMode: String, CaseIterable, Identifiable { case general, apps, windows }`, `static let lastModeDefaultsKey = "settings_last_mode"`, `static func initial(requested: SettingsMode?, storedRawValue: String?) -> SettingsMode`
  - `SettingsNavigationState(selectedMode: SettingsMode = .general, defaults: UserDefaults = .standard)`. `selectedMode`가 바뀌면 `defaults`에 rawValue를 저장한다.

이 Task는 화면을 새 모드에 **임시로 이어 붙이기만** 한다. 화면 재구성은 Task 4~6에서 한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/ZapAppTests/SettingsNavigationTests.swift`:

```swift
import XCTest
@testable import ZapApp

final class SettingsNavigationTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "SettingsNavigationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    func testSettingsModesAreGeneralAppsWindowsInOrder() {
        XCTAssertEqual(SettingsMode.allCases.map(\.title), ["General", "Apps", "Windows"])
        XCTAssertEqual(SettingsMode.allCases.map(\.systemImage), ["gearshape", "square.grid.2x2", "rectangle.3.group"])
    }

    func testInitialModeDefaultsToGeneral() {
        XCTAssertEqual(SettingsMode.initial(requested: nil, storedRawValue: nil), .general)
    }

    func testInitialModeUsesStoredLastMode() {
        XCTAssertEqual(SettingsMode.initial(requested: nil, storedRawValue: "windows"), .windows)
    }

    func testInitialModePrefersRequestedModeOverStoredMode() {
        XCTAssertEqual(SettingsMode.initial(requested: .apps, storedRawValue: "windows"), .apps)
    }

    func testInitialModeFallsBackToGeneralForUnknownStoredValue() {
        for stale in ["automatic", "manual", "windowManagement", "about", ""] {
            XCTAssertEqual(SettingsMode.initial(requested: nil, storedRawValue: stale), .general, stale)
        }
    }

    func testSelectingModePersistsLastMode() {
        let defaults = makeDefaults()
        let state = SettingsNavigationState(selectedMode: .general, defaults: defaults)

        XCTAssertNil(defaults.string(forKey: SettingsMode.lastModeDefaultsKey))

        state.selectedMode = .windows

        XCTAssertEqual(defaults.string(forKey: SettingsMode.lastModeDefaultsKey), "windows")
    }
}
```

`Tests/ZapAppTests/SettingsWindowManagementUITests.swift`에서:

1. `testSettingsModeIncludesShortcutModesAndGeneral`를 **삭제**한다(새 파일의 `testSettingsModesAreGeneralAppsWindowsInOrder`가 대체).
2. `testSettingsViewRoutesWindowManagementModeAndKeepsExistingModes`를 아래로 교체한다:

```swift
    func testSettingsViewRoutesThreeModes() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("case general"))
        XCTAssertTrue(source.contains("case apps"))
        XCTAssertTrue(source.contains("case windows"))
        XCTAssertTrue(source.contains("case .windows:"))
        XCTAssertTrue(source.contains("WindowManagementSettingsView"))
        XCTAssertFalse(source.contains("case automatic"))
        XCTAssertFalse(source.contains("case manual"))
        XCTAssertFalse(source.contains("case windowManagement"))
        XCTAssertFalse(source.contains("case about"))
    }
```

3. `testSettingsWindowPreservesStateAndCanRouteToRequestedMode`에서 아래 한 줄을

```swift
        XCTAssertTrue(presenterSource.contains("navigationState = SettingsNavigationState(selectedMode: initialMode ?? .automatic)"))
```

다음 두 줄로 바꾼다:

```swift
        XCTAssertTrue(presenterSource.contains("SettingsMode.initial(\n                    requested: initialMode,"))
        XCTAssertTrue(presenterSource.contains("storedRawValue: UserDefaults.standard.string(forKey: SettingsMode.lastModeDefaultsKey)"))
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build" --filter "SettingsNavigationTests|SettingsWindowManagementUITests"`
Expected: 컴파일 실패, "type 'SettingsMode' has no member 'initial'"

- [ ] **Step 3: 구현**

`SettingsView.swift` 맨 위 `SettingsNavigationState`를 교체한다:

```swift
final class SettingsNavigationState: ObservableObject {
    @Published var selectedMode: SettingsMode {
        didSet {
            defaults.set(selectedMode.rawValue, forKey: SettingsMode.lastModeDefaultsKey)
        }
    }

    private let defaults: UserDefaults

    init(selectedMode: SettingsMode = .general, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectedMode = selectedMode
    }
}
```

`SettingsView.init`의 `initialMode: SettingsMode = .automatic` 기본값을 `.general`로 바꾼다.

`enum SettingsMode` 전체를 교체한다:

```swift
enum SettingsMode: String, CaseIterable, Identifiable {
    case general
    case apps
    case windows

    static let lastModeDefaultsKey = "settings_last_mode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .apps: "Apps"
        case .windows: "Windows"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .apps: "square.grid.2x2"
        case .windows: "rectangle.3.group"
        }
    }

    static func initial(requested: SettingsMode?, storedRawValue: String?) -> SettingsMode {
        requested ?? storedRawValue.flatMap(SettingsMode.init(rawValue:)) ?? .general
    }
}
```

`body`의 `switch selectedMode { ... }`를 임시로 아래처럼 바꾼다(다음 Task들에서 다시 바꾼다):

```swift
                    switch selectedMode {
                    case .general:
                        generalSection
                        aboutSection
                    case .apps:
                        automaticShortcutsSection
                        automaticSection
                        manualSection
                    case .windows:
                        WindowManagementSettingsView(
                            model: model.windowManagementModel,
                            registrationError: model.registrationError,
                            inputSourceRevision: model.inputSourceRevision
                        )
                    }
```

`settingsSidebar`의 두 `sidebarSection(...)` 호출을 아래 한 줄로 바꾼다(사이드바 모양은 Task 4에서 다듬는다):

```swift
            sidebarSection(title: "Settings", modes: SettingsMode.allCases)
```

`addManualShortcut()`의 `selectedMode = .manual`을 `selectedMode = .apps`로 바꾼다.

`SettingsWindowPresenter.swift`의 `if window == nil {` 블록 첫 줄을 바꾼다:

```swift
        if window == nil {
            navigationState = SettingsNavigationState(
                selectedMode: SettingsMode.initial(
                    requested: initialMode,
                    storedRawValue: UserDefaults.standard.string(forKey: SettingsMode.lastModeDefaultsKey)
                )
            )
            window = makeWindow(model: model, updateService: updateService, showMenuBarIcon: showMenuBarIcon)
        } else if let initialMode {
```

- [ ] **Step 4: 남은 깨진 단언 정리**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build" --filter SettingsWindowManagementUITests`

`testSettingsSidebarGroupsShortcutModesAndSystemGeneral`와 `testSettingsAboutModeRendersExistingAboutViewWithoutExtraCardWrapper`는 Task 4에서 교체하므로, 지금은 두 함수의 본문 첫 줄에 `throw XCTSkip("Replaced in Task 4")`를 넣는다. 그 밖의 테스트는 모두 PASS여야 한다.

- [ ] **Step 5: 전체 테스트 통과 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build"`
Expected: 전체 PASS(skip 2개)

- [ ] **Step 6: 커밋**

```bash
git add Sources/ZapApp/Views/SettingsView.swift Sources/ZapApp/Services/SettingsWindowPresenter.swift Tests/ZapAppTests/SettingsNavigationTests.swift Tests/ZapAppTests/SettingsWindowManagementUITests.swift
git commit -m "feat: reduce settings to general, apps, windows and remember last screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: 사이드바와 General 화면 (About 제거, AppDistribution, 배너)

**Files:**
- Create: `Sources/ZapApp/Models/AppDistribution.swift`
- Modify: `Sources/ZapApp/Views/SettingsView.swift` (`body` switch의 `.general`, `settingsSidebar`, `sidebarSection` 삭제, `generalSection`, `aboutSection` 삭제, `permissionsSection` 부제, `shortcutControlsSection`, `updatesSection`)
- Test: `Tests/ZapAppTests/AppDistributionTests.swift` (새 파일)
- Test: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`, `Tests/ZapAppTests/SettingsShortcutControlsUITests.swift`

**Interfaces:**
- Consumes: `SettingsIssueBanner(messages:)` (Task 2), `SettingsMode.allCases` (Task 3)
- Produces: `enum AppDistribution { case direct, appStore; static var current: AppDistribution; var supportsInAppUpdates: Bool }` (Task 7에서 사용)

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/ZapAppTests/AppDistributionTests.swift`:

```swift
import XCTest
@testable import ZapApp

final class AppDistributionTests: XCTestCase {
    func testOnlyDirectDistributionSupportsInAppUpdates() {
        XCTAssertTrue(AppDistribution.direct.supportsInAppUpdates)
        XCTAssertFalse(AppDistribution.appStore.supportsInAppUpdates)
    }

    func testDefaultBuildIsDirectDistribution() {
        XCTAssertEqual(AppDistribution.current, .direct)
    }
}
```

`SettingsWindowManagementUITests.swift`에서:

1. `testSettingsSidebarGroupsShortcutModesAndSystemGeneral`를 아래로 교체한다:

```swift
    func testSettingsSidebarListsModesWithoutSectionHeadersAndShowsVersion() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("ForEach(SettingsMode.allCases) { mode in"))
        XCTAssertFalse(source.contains("sidebarSection("))
        XCTAssertFalse(source.contains("\"Shortcuts\", modes:"))
        XCTAssertFalse(source.contains("\"System\", modes:"))
        XCTAssertTrue(source.contains("Text(sidebarVersionLine)"))
        XCTAssertTrue(source.contains("AboutPresentation(appName: AboutPresentation.currentAppName, info: AboutInfo.current).versionLine"))
    }
```

2. `testSettingsAboutModeRendersExistingAboutViewWithoutExtraCardWrapper`를 아래로 교체한다:

```swift
    func testSettingsNoLongerHasAboutScreen() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertFalse(source.contains("aboutSection"))
        XCTAssertFalse(source.contains("AboutView("))
        XCTAssertFalse(source.contains("case .about"))
    }
```

3. `testGeneralSectionOwnsPermissionsBehaviorAndUpdates`에서
   `XCTAssertTrue(source.contains("Drag Zap into the list to let it move and resize windows."))`를
   `XCTAssertTrue(source.contains("Required for window shortcuts and per-app toggling."))`로 바꾸고, 함수 끝에 아래를 추가한다:

```swift
        XCTAssertTrue(source.contains("if AppDistribution.current.supportsInAppUpdates {\n                updatesSection\n            }"))
        XCTAssertTrue(source.contains("case .general:\n                        SettingsIssueBanner(messages: [model.registrationError])\n                        generalSection"))
```

4. `testSettingsStillContainsBehaviorAndSparkleUpdateControls`를 아래로 교체한다:

```swift
    func testSettingsContainsBehaviorAndUpdateControlsWithoutSparkleCopy() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("SettingsCard(title: \"Behavior\")"))
        XCTAssertTrue(source.contains("Launch at login"))
        XCTAssertTrue(source.contains("Show menu bar icon"))
        XCTAssertTrue(source.contains("SettingsCard(title: \"Updates\")"))
        XCTAssertTrue(source.contains("Automatically check for updates"))
        XCTAssertTrue(source.contains("Button(\"Check Now\")"))
        XCTAssertFalse(source.contains("Check for Updates Now"))
        XCTAssertFalse(source.contains("Sparkle"))
    }
```

`SettingsShortcutControlsUITests.swift`에서 `testShortcutControlsDisplaysGlobalRegistrationError`를 아래로 교체한다:

```swift
    func testShortcutControlsLeavesRegistrationErrorToBanner()
        throws {
        let source = try settingsSource
        let sectionStart = try XCTUnwrap(source.range(
            of: "    private var shortcutControlsSection: some View {"
        ))
        let sectionEnd = try XCTUnwrap(source.range(
            of: "    private var ",
            range: sectionStart.upperBound..<source.endIndex
        ))
        let sectionSource = String(source[sectionStart.lowerBound..<sectionEnd.lowerBound])

        XCTAssertFalse(sectionSource.contains("registrationError"))
    }
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build" --filter "AppDistributionTests|SettingsWindowManagementUITests|SettingsShortcutControlsUITests"`
Expected: 컴파일 실패, "cannot find 'AppDistribution' in scope"

- [ ] **Step 3: AppDistribution 구현**

`Sources/ZapApp/Models/AppDistribution.swift`:

```swift
enum AppDistribution: Equatable {
    case direct
    case appStore

    static var current: AppDistribution {
        #if ZAP_APP_STORE
        .appStore
        #else
        .direct
        #endif
    }

    var supportsInAppUpdates: Bool {
        self == .direct
    }
}
```

- [ ] **Step 4: SettingsView의 사이드바와 General 구현**

`body` switch의 `.general` 분기를 바꾼다:

```swift
                    case .general:
                        SettingsIssueBanner(messages: [model.registrationError])
                        generalSection
```

`settingsSidebar`와 `sidebarSection(title:modes:)`을 아래 두 프로퍼티로 교체한다(`sidebarSection` 함수는 삭제):

```swift
    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 9) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(AboutPresentation.currentAppName)
                        .font(.system(size: 13, weight: .semibold))
                    Text("Keyboard-first control")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 15)

            ForEach(SettingsMode.allCases) { mode in
                SettingsSidebarItem(
                    mode: mode,
                    isSelected: selectedMode == mode
                ) {
                    selectedMode = mode
                }
            }

            Spacer()

            Text(sidebarVersionLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
        }
        .padding(14)
        .frame(width: 216)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.bar)
    }

    private var sidebarVersionLine: String {
        AboutPresentation(appName: AboutPresentation.currentAppName, info: AboutInfo.current).versionLine
    }
```

`generalSection`을 교체하고 `aboutSection` 프로퍼티는 삭제한다:

```swift
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.large) {
            permissionsSection
            shortcutControlsSection
            behaviorSection
            if AppDistribution.current.supportsInAppUpdates {
                updatesSection
            }
        }
    }
```

`permissionsSection`의 `subtitle:`을 `"Required for window shortcuts and per-app toggling."`로 바꾼다.

`shortcutControlsSection`에서 맨 끝의 `if let registrationError = model.registrationError { Label(...) ... }` 블록을 삭제한다.

`updatesSection`을 교체한다:

```swift
    private var updatesSection: some View {
        SettingsCard(title: "Updates") {
            Toggle("Automatically check for updates", isOn: $updateService.automaticallyChecksForUpdates)

            HStack {
                Spacer()
                Button("Check Now") {
                    updateService.checkForUpdates()
                }
            }
        }
    }
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build"`
Expected: 전체 PASS, skip 0개

- [ ] **Step 6: 커밋**

```bash
git add Sources/ZapApp/Models/AppDistribution.swift Sources/ZapApp/Views/SettingsView.swift Tests/ZapAppTests/AppDistributionTests.swift Tests/ZapAppTests/SettingsWindowManagementUITests.swift Tests/ZapAppTests/SettingsShortcutControlsUITests.swift
git commit -m "feat: simplify settings sidebar and general screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Apps 화면 (Dock Apps + Custom Apps)

**Files:**
- Modify: `Sources/ZapApp/Views/SettingsView.swift` (`body` switch의 `.apps`, `automaticShortcutsSection`·`automaticSection`·`manualSection` 삭제 후 `dockAppsSection`·`customAppsSection` 추가, `dockModifierSelector`, `ShortcutListRow`)
- Test: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`

**Interfaces:**
- Consumes: `SettingsCard(title:subtitle:content:accessory:)`, `SettingsIssueBanner(messages:)` (Task 2)
- Produces: 없음

- [ ] **Step 1: 실패하는 테스트로 교체**

`SettingsWindowManagementUITests.swift`에서:

1. `testAutomaticDockAppsAlwaysIncludesFinderWithDisabledVisualState`, `testFinderShortcutUsesSwitchToggleStyle`, `testAutomaticAndManualShortcutControlsRemainWired` 세 함수를 **삭제**하고 아래 세 함수를 추가한다:

```swift
    func testAppsScreenCombinesDockAppsAndCustomApps() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("case .apps:\n                        SettingsIssueBanner(messages: [model.registrationError])\n                        dockAppsSection\n                        customAppsSection"))
        XCTAssertTrue(source.contains("SettingsCard(title: \"Dock Apps\", subtitle: \"Your first nine pinned Dock apps, in order.\")"))
        XCTAssertTrue(source.contains("SettingsCard(title: \"Custom Apps\", subtitle: \"Any app, any shortcut.\")"))
        XCTAssertTrue(source.contains("Button(\"Add App…\")"))
        XCTAssertTrue(source.contains("Text(\"No custom apps yet\")"))
        XCTAssertTrue(source.contains("Label(\"Refresh\", systemImage: \"arrow.clockwise\")"))
        XCTAssertTrue(source.contains("Text(\"Modifier\")"))
        XCTAssertTrue(source.contains("Text(\"+ 1–9\")"))
        XCTAssertTrue(source.contains("ManualShortcutRow("))
        XCTAssertFalse(source.contains("automaticShortcutsSection"))
        XCTAssertFalse(source.contains("manualSection"))
        XCTAssertFalse(source.contains("Refresh the Dock when pinned apps change."))
        XCTAssertFalse(source.contains("Dock app shortcuts"))
        XCTAssertFalse(source.contains("Add App Shortcut"))
        XCTAssertFalse(source.contains("No manual shortcuts"))
    }

    func testFinderRowCarriesItsOwnSwitchAndAlwaysShows() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("ShortcutListRow(\n                    shortcut: model.finderShortcutTitle,\n                    title: \"Finder\",\n                    isDisabled: !model.isFinderShortcutEnabled,\n                    isOn: $model.isFinderShortcutEnabled\n                )"))
        XCTAssertTrue(source.contains("var isOn: Binding<Bool>? = nil"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"Finder shortcut\")"))
        XCTAssertFalse(source.contains("Toggle(\"Finder shortcut\", isOn: $model.isFinderShortcutEnabled)"))
    }

    func testFinderRowDimsOnlyKeycapAndTitleNotSwitch() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))
        let rowStart = try XCTUnwrap(source.range(of: "private struct ShortcutListRow: View {"))
        let rowEnd = try XCTUnwrap(source.range(of: "private struct ManualShortcutRow: View {"))
        let rowSource = String(source[rowStart.lowerBound..<rowEnd.lowerBound])

        XCTAssertTrue(rowSource.contains("            .opacity(isDisabled ? 0.62 : 1)\n\n            if let isOn {"))
        XCTAssertFalse(rowSource.contains("        .opacity(isDisabled ? 0.62 : 1)\n    }\n}"))
    }
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build" --filter SettingsWindowManagementUITests`
Expected: FAIL. `testAppsScreenCombinesDockAppsAndCustomApps`, `testFinderRowCarriesItsOwnSwitchAndAlwaysShows`, `testFinderRowDimsOnlyKeycapAndTitleNotSwitch`가 실패한다.

- [ ] **Step 3: 구현**

`body` switch의 `.apps` 분기를 교체한다:

```swift
                    case .apps:
                        SettingsIssueBanner(messages: [model.registrationError])
                        dockAppsSection
                        customAppsSection
```

`automaticShortcutsSection`, `automaticSection`, `manualSection` 프로퍼티를 **삭제**하고, 아래 두 프로퍼티를 추가한다. `automaticShortcutColumns`, `addManualShortcut()`은 그대로 둔다.

```swift
    private var dockAppsSection: some View {
        SettingsCard(title: "Dock Apps", subtitle: "Your first nine pinned Dock apps, in order.") {
            dockModifierSelector

            LazyVGrid(columns: automaticShortcutColumns, alignment: .leading, spacing: 8) {
                ShortcutListRow(
                    shortcut: model.finderShortcutTitle,
                    title: "Finder",
                    isDisabled: !model.isFinderShortcutEnabled,
                    isOn: $model.isFinderShortcutEnabled
                )

                ForEach(NumberKey.allCases) { key in
                    ShortcutListRow(
                        shortcut: model.shortcutTitle(for: key),
                        title: model.dockItem(for: key)?.name ?? "Empty",
                        isEmpty: model.dockItem(for: key) == nil
                    )
                }
            }
        } accessory: {
            Button {
                model.refreshDockItems()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
        }
    }

    private var customAppsSection: some View {
        SettingsCard(title: "Custom Apps", subtitle: "Any app, any shortcut.") {
            if model.manualShortcuts.isEmpty {
                Text("No custom apps yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
            }

            ForEach(model.manualShortcuts) { shortcut in
                ManualShortcutRow(
                    shortcut: shortcut,
                    setEnabled: { model.setManualShortcutEnabled(id: shortcut.id, isEnabled: $0) },
                    record: { recordingShortcut = shortcut },
                    remove: { model.removeManualShortcut(id: shortcut.id) }
                )
            }
        } accessory: {
            Button("Add App…") {
                addManualShortcut()
            }
            .controlSize(.small)
        }
    }
```

`dockModifierSelector`를 교체한다:

```swift
    private var dockModifierSelector: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Modifier")

            Spacer()

            HStack(spacing: 5) {
                ForEach(ShortcutModifier.allCases) { modifier in
                    ModifierKeyButton(
                        modifier: modifier,
                        isSelected: model.selectedModifiers.contains(modifier)
                    ) {
                        model.setModifier(modifier, isEnabled: !model.selectedModifiers.contains(modifier))
                    }
                }

                Text("+ 1–9")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
```

`ShortcutListRow`를 교체한다:

```swift
private struct ShortcutListRow: View {
    let shortcut: String
    let title: String
    var isEmpty = false
    var isDisabled = false
    var isOn: Binding<Bool>? = nil

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                ShortcutKeycapGroupView(shortcut: shortcut, isDisabled: isEmpty || isDisabled)
                    .frame(width: 80, alignment: .leading)
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isEmpty || isDisabled ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(isDisabled ? 0.62 : 1)

            if let isOn {
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .accessibilityLabel("Finder shortcut")
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(isEmpty ? 0.025 : 0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build"`
Expected: 전체 PASS

- [ ] **Step 5: 커밋**

```bash
git add Sources/ZapApp/Views/SettingsView.swift Tests/ZapAppTests/SettingsWindowManagementUITests.swift
git commit -m "feat: merge automatic and manual shortcuts into apps screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Windows 화면 (단일 열 목록, 제목 줄 accessory, 배너)

**Files:**
- Modify: `Sources/ZapApp/Views/WindowManagementSettingsView.swift` (전체 `body`, `shortcutsSection`, `shortcutErrorMessages` 삭제, `WindowShortcutCategoryGroup`, `WindowActionCategory.systemImage` 삭제)
- Test: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`

**Interfaces:**
- Consumes: `SettingsCard(title:subtitle:content:accessory:)`, `SettingsIssueBanner(messages:)` (Task 2)
- Produces: 없음. `WindowManagementSettingsView(model:registrationError:inputSourceRevision:)` 시그니처는 유지한다.

- [ ] **Step 1: 실패하는 테스트로 교체**

`SettingsWindowManagementUITests.swift`에서 아래 다섯 함수를 **삭제**한다:
`testWindowManagementUsesSharedAdaptiveTwoColumnRowsForEveryCategory`,
`testWindowManagementSettingsDeletesStatusCardButKeepsInlineErrors`,
`testWindowManagementGlobalToggleRemainsAvailableWithoutAccessibilityPermission`,
`testWindowManagementSettingsReceivesAndDisplaysGlobalRegistrationError`,
`testWindowManagementPositioningCategoryUsesSharedTwoColumnGrid`.

그리고 아래 세 함수를 추가한다:

```swift
    func testWindowsScreenUsesSingleColumnRowsWithDividers() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

        XCTAssertFalse(source.contains("LazyVGrid"))
        XCTAssertFalse(source.contains("shortcutColumns"))
        XCTAssertTrue(source.contains("ForEach(Array(shortcuts.enumerated()), id: \\.element.id) { index, shortcut in"))
        XCTAssertTrue(source.contains("if index > 0 {\n                        Divider()\n                    }"))
        XCTAssertTrue(source.contains(".textCase(.uppercase)"))
        XCTAssertFalse(source.contains("category.systemImage"))
    }

    func testWindowsCardPutsEnableSwitchAndResetInTitleRow() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

        XCTAssertTrue(source.contains("SettingsCard(title: \"Window Shortcuts\")"))
        XCTAssertFalse(source.contains("Grouped by what each shortcut changes"))
        XCTAssertTrue(source.contains("} accessory: {"))
        XCTAssertTrue(source.contains("Toggle(\"Enable window management shortcuts\", isOn: Binding("))
        XCTAssertTrue(source.contains(".labelsHidden()"))
        XCTAssertTrue(source.contains("Button(\"Reset to Defaults\")"))
        XCTAssertFalse(source.contains(".disabled(!model.accessibilityTrusted)"))
        XCTAssertTrue(source.contains("isLocked: !model.accessibilityTrusted"))
        XCTAssertTrue(source.contains("Grant \\(AccessibilityPaneName.current) in General to use window shortcuts."))
    }

    func testWindowsScreenShowsAllErrorsInOneBanner() throws {
        let settingsSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

        XCTAssertTrue(settingsSource.contains("registrationError: model.registrationError"))
        XCTAssertTrue(source.contains("SettingsIssueBanner(messages: [\n                registrationError,\n                model.shortcutRegistrationError,\n                model.windowManagementError\n            ])"))
        XCTAssertFalse(source.contains("shortcutErrorMessages"))
        XCTAssertFalse(source.contains("Label(registrationError"))
    }
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build" --filter SettingsWindowManagementUITests`
Expected: 새로 추가한 세 테스트가 FAIL

- [ ] **Step 3: 구현**

`WindowManagementSettingsView`의 `body`, `shortcutsSection`을 교체하고 `shortcutErrorMessages`는 삭제한다. `init`과 `shortcutsByCategory`는 그대로 둔다.

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: ZapSpacing.large) {
            SettingsIssueBanner(messages: [
                registrationError,
                model.shortcutRegistrationError,
                model.windowManagementError
            ])

            shortcutsSection
        }
    }

    private var shortcutsSection: some View {
        SettingsCard(title: "Window Shortcuts") {
            if !model.accessibilityTrusted {
                Label("Grant \(AccessibilityPaneName.current) in General to use window shortcuts.", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(WindowActionCategory.allCases, id: \.self) { category in
                    if let shortcuts = shortcutsByCategory[category], !shortcuts.isEmpty {
                        WindowShortcutCategoryGroup(
                            category: category,
                            shortcuts: shortcuts,
                            isLocked: !model.accessibilityTrusted,
                            inputSourceRevision: inputSourceRevision,
                            setEnabled: { shortcut, isEnabled in
                                model.setShortcutEnabled(action: shortcut.action, isEnabled: isEnabled)
                            },
                            setRecordingActive: { isRecording in
                                model.setShortcutRecordingActive(isRecording)
                            },
                            record: { shortcut, recordedShortcut in
                                model.setShortcut(
                                    action: shortcut.action,
                                    keyCode: recordedShortcut.keyCode,
                                    keyDisplayName: recordedShortcut.keyDisplayName,
                                    modifiers: recordedShortcut.modifiers
                                )
                            }
                        )
                    }
                }
            }
        } accessory: {
            HStack(spacing: ZapSpacing.medium) {
                Toggle("Enable window management shortcuts", isOn: Binding(
                    get: { model.isWindowManagementEnabled },
                    set: { model.setWindowManagementEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()

                Button("Reset to Defaults") {
                    model.resetShortcutsToDefaults()
                }
                .controlSize(.small)
            }
        }
    }
```

`WindowShortcutCategoryGroup`을 교체한다(`shortcutColumns` 삭제):

```swift
private struct WindowShortcutCategoryGroup: View {
    let category: WindowActionCategory
    let shortcuts: [WindowShortcut]
    let isLocked: Bool
    let inputSourceRevision: Int
    let setEnabled: (WindowShortcut, Bool) -> Void
    let setRecordingActive: (Bool) -> Void
    let record: (WindowShortcut, RecordedShortcut) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(category.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    if index > 0 {
                        Divider()
                    }

                    WindowShortcutRowView(
                        shortcut: shortcut,
                        isLocked: isLocked,
                        inputSourceRevision: inputSourceRevision,
                        setEnabled: { isEnabled in setEnabled(shortcut, isEnabled) },
                        setRecordingActive: setRecordingActive,
                        record: { recordedShortcut in record(shortcut, recordedShortcut) }
                    )
                }
            }
        }
        .opacity(isLocked ? 0.72 : 1)
    }
}
```

파일 끝의 `private extension WindowActionCategory`에서 `systemImage` 프로퍼티를 삭제하고 `title`만 남긴다.

- [ ] **Step 4: 테스트 통과 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build"`
Expected: 전체 PASS. `testWindowManagementSettingsGroupsShortcutsByCategoryAndLocksWhenPermissionIsMissing`, `testWindowManagementGlobalToggleUsesSwitchStyle`, `testWindowManagementSettingsViewContainsEnableResetAndShortcutRows`도 그대로 통과해야 한다.

- [ ] **Step 5: 커밋**

```bash
git add Sources/ZapApp/Views/WindowManagementSettingsView.swift Tests/ZapAppTests/SettingsWindowManagementUITests.swift
git commit -m "feat: list window shortcuts in a single column with one error banner

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: 메뉴바 About Zap 항목과 업데이트 항목 조건부 표시

**Files:**
- Modify: `Sources/ZapApp/Views/MenuBarView.swift:4-35`
- Modify: `Sources/ZapApp/ZapApp.swift:23-42`
- Test: `Tests/ZapAppTests/MenuBarViewTests.swift`

**Interfaces:**
- Consumes: `AppDistribution.current.supportsInAppUpdates` (Task 4), `AboutWindowPresenter.open()`, `AboutPresentation.aboutMenuLabel(appName:)` (기존)
- Produces: `MenuBarView(model:updateService:openAbout:openSettings:quit:)`

- [ ] **Step 1: 실패하는 테스트 작성**

`MenuBarViewTests.swift`에 추가한다:

```swift
    func testMenuBarOffersAboutBeforeSettings() throws {
        let source = try menuBarSource
        let app = try appSource

        XCTAssertTrue(source.contains("let openAbout: () -> Void"))
        XCTAssertTrue(source.contains("Button(AboutPresentation.aboutMenuLabel(appName: AboutPresentation.currentAppName)) {\n            openAbout()\n        }\n        Button(\"Settings...\")"))
        XCTAssertTrue(app.contains("openAbout: { AboutWindowPresenter.open() },"))
    }

    func testUpdateItemsAppearOnlyForDirectDistribution() throws {
        let source = try menuBarSource
        let app = try appSource

        XCTAssertTrue(source.contains("if AppDistribution.current.supportsInAppUpdates {\n            Button(\"Check for Updates...\")"))
        XCTAssertTrue(app.contains("if AppDistribution.current.supportsInAppUpdates {\n                    Button(\"Check for Updates...\")"))
    }
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build" --filter MenuBarViewTests`
Expected: 새 두 테스트 FAIL

- [ ] **Step 3: 구현**

`MenuBarView`에서 `let openSettings: () -> Void` 위에 `let openAbout: () -> Void`를 추가하고, `body`의 `Refresh Dock Apps` 이후 부분을 교체한다:

```swift
        Button("Refresh Dock Apps") {
            model.refreshDockItems()
        }
        if AppDistribution.current.supportsInAppUpdates {
            Button("Check for Updates...") {
                updateService.checkForUpdates()
            }
        }

        Divider()

        Button(AboutPresentation.aboutMenuLabel(appName: AboutPresentation.currentAppName)) {
            openAbout()
        }
        Button("Settings...") {
            openSettings()
        }
        Button("Quit \(AboutPresentation.currentAppName)") {
            quit()
        }
```

`ZapApp.swift`의 `MenuBarView(...)` 호출을 교체한다:

```swift
            MenuBarView(
                model: model,
                updateService: updateService,
                openAbout: { AboutWindowPresenter.open() },
                openSettings: { openSettings() },
                quit: { NSApp.terminate(nil) }
            )
```

`CommandGroup(replacing: .appSettings)` 안의 업데이트 버튼을 감싼다:

```swift
                if AppDistribution.current.supportsInAppUpdates {
                    Button("Check for Updates...") {
                        updateService.checkForUpdates()
                    }
                }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build"`
Expected: 전체 PASS. 기존 `testMenuBarUsesNativeQuickLaunchAndWindowControlSubmenus`도 통과해야 한다(`Button("Check for Updates...")` 문자열이 여전히 있음).

- [ ] **Step 5: 커밋**

```bash
git add Sources/ZapApp/Views/MenuBarView.swift Sources/ZapApp/ZapApp.swift Tests/ZapAppTests/MenuBarViewTests.swift
git commit -m "feat: add About Zap menu item and gate update items by distribution

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: 실제 앱 확인, 스크린샷과 README 갱신

**Files:**
- Modify: `README.md:10-13`
- Create: `assets/screenshots/settings-apps.png`, `assets/screenshots/settings-windows.png`
- Delete: `assets/screenshots/settings-automatic.png`, `assets/screenshots/settings-window-management.png`, `assets/screenshots/settings-manual.png`

**Interfaces:**
- Consumes: Task 1~7의 결과
- Produces: 없음

- [ ] **Step 1: 앱 실행**

Run: `make dev-run` (`.build`에서 codesign이 실패하면 `xattr -cr .build`를 실행한 뒤 다시 시도하고, 그래도 실패하면 사용자에게 알린다.)

- [ ] **Step 2: 수동 확인 체크리스트**

- 처음 열면 General이 뜨는지(`defaults delete <bundle id> settings_last_mode` 후 확인)
- Windows로 이동하고 창을 닫았다가 다시 열면 Windows가 뜨는지
- General: Permissions → Shortcut Controls → Behavior → Updates 순서, Sparkle 문구 없음, 사이드바 하단에 버전 표시
- Apps: Refresh와 Add App… 버튼이 카드 제목 줄에 있는지, Finder 스위치를 끄면 행만 흐려지고 스위치는 다시 켤 수 있는지
- Windows: 단일 열 목록, 이름 잘림 없음, Fullscreen keycap이 `↩` 한 칸으로 보이는지, 제목 줄의 스위치와 Reset to Defaults
- 메뉴바: `About Zap`을 누르면 About 창이 열리는지

- [ ] **Step 3: 스크린샷 교체**

Apps 화면과 Windows 화면을 기존 스크린샷과 같은 방식(창 단위 캡처, `⌘⇧4` → `Space`)으로 캡처해 `assets/screenshots/settings-apps.png`, `assets/screenshots/settings-windows.png`로 저장한다. 그다음 기존 세 파일을 삭제한다:

```bash
git rm assets/screenshots/settings-automatic.png assets/screenshots/settings-window-management.png assets/screenshots/settings-manual.png
```

- [ ] **Step 4: README 갱신**

`README.md`의 두 `<img>` 줄을 바꾼다:

```html
  <img src="assets/screenshots/settings-apps.png" alt="Zap Settings Apps screen" width="92%">
```

```html
  <img src="assets/screenshots/settings-windows.png" alt="Zap Settings Windows screen" width="92%">
```

- [ ] **Step 5: 전체 테스트 재확인과 커밋**

Run: `swift test --scratch-path "$HOME/Library/Caches/zap-build"`
Expected: 전체 PASS

```bash
git add README.md assets/screenshots/settings-apps.png assets/screenshots/settings-windows.png
git commit -m "docs: update settings screenshots for new layout

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
