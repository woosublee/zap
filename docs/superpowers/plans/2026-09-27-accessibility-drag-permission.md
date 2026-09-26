# Accessibility Drag Permission Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Zap's `AXIsProcessTrustedWithOptions` prompt with a PermissionFlow drag-to-authorize panel, started from the Settings `Grant…` button and (once per session) from a window shortcut pressed without permission.

**Architecture:** Pure presentation logic (session throttle, OS-specific pane name, click source frame) lives in a PermissionFlow-free file. A single wrapper `AccessibilityPermissionGuide` is the only file importing PermissionFlow. `WindowManagementModel` owns the guide and throttle; `WindowManagementService` is untouched. The Makefile copies PermissionFlow's resource bundle into `Contents/Resources`.

**Tech Stack:** Swift 5.10 manifest (toolchain Swift 6.4), SwiftUI + AppKit, XCTest, SwiftPM, GNU Make, `codesign`.

**Spec:** `docs/superpowers/specs/2026-09-27-accessibility-drag-permission-design.md`

## Global Constraints

- Dependency: `.package(url: "https://github.com/jaywcjlove/PermissionFlow", exact: "2.11.2")`; link only the `PermissionFlow` product.
- Do not change Zap's `// swift-tools-version: 5.10` or `platforms: [.macOS(.v13)]`.
- `PermissionFlow` is imported only in `Sources/ZapApp/Services/AccessibilityPermissionGuide.swift`.
- PermissionFlow configuration: `requiredAppURLs: [Bundle.main.bundleURL]`, `promptForAccessibilityTrust: false`.
- Pane names (English, Zap UI is English): macOS ≥ 27 → `Device Control and Data Access`; earlier → `Accessibility`.
- Button title `Grant…` (U+2026 ellipsis). Subtitle: `Drag Zap into the list to let it move and resize windows.`
- Shortcut-path guide shows at most once per app session (in-memory only).
- Resource bundle name: `PermissionFlow_PermissionFlow.bundle`, destination `Contents/Resources/`.
- Run tests with `swift test` (or `swift test --filter <TestClass>`) from the repo root.

## Review Focus

1. Permission already granted when `Grant…` / shortcut path fires → no System Settings, no panel. (Task 2 test `testStartDoesNothingWhenAlreadyTrusted`.)
2. Rapid repeated window shortcuts without permission → guide starts once only. (Task 3 test `testMissingPermissionStartsGuideOncePerSession`.)
3. Other window failures (`.focusedWindowMissing`) must not start the guide. (Task 3 test `testOtherFailuresDoNotStartGuide`.)
4. Missing resource bundle in the built `.app` → build fails loudly, not silently English/keys. (Task 2 Makefile `test -d` + `ReleaseWorkflowTests` assertion.)
5. macOS 27 renamed the page; the Settings row must not say "Accessibility" there. (Task 1 test `testPaneNameUsesDeviceControlOnMacOS27AndLater`.)

---

### Task 1: Pure guide presentation logic

**Files:**
- Create: `Sources/ZapApp/Models/PermissionGuidePresentation.swift`
- Test: `Tests/ZapAppTests/PermissionGuidePresentationTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `struct PermissionGuideThrottle { mutating func shouldStart() -> Bool }`
  - `enum AccessibilityPaneName { static func title(for: OperatingSystemVersion) -> String; static var current: String }`
  - `enum PermissionGuideSourceFrame { static func around(_ point: CGPoint) -> CGRect; @MainActor static var atMouse: CGRect }`

- [ ] **Step 1: Write the failing tests**

`Tests/ZapAppTests/PermissionGuidePresentationTests.swift`:

```swift
import CoreGraphics
import XCTest
@testable import ZapApp

final class PermissionGuidePresentationTests: XCTestCase {
    func testThrottleAllowsOnlyFirstStart() {
        var throttle = PermissionGuideThrottle()

        XCTAssertTrue(throttle.shouldStart())
        XCTAssertFalse(throttle.shouldStart())
        XCTAssertFalse(throttle.shouldStart())
    }

    func testPaneNameUsesAccessibilityBeforeMacOS27() {
        let version = OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0)

        XCTAssertEqual(AccessibilityPaneName.title(for: version), "Accessibility")
    }

    func testPaneNameUsesDeviceControlOnMacOS27AndLater() {
        let v27 = OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
        let v28 = OperatingSystemVersion(majorVersion: 28, minorVersion: 1, patchVersion: 0)

        XCTAssertEqual(AccessibilityPaneName.title(for: v27), "Device Control and Data Access")
        XCTAssertEqual(AccessibilityPaneName.title(for: v28), "Device Control and Data Access")
    }

    func testSourceFrameIsCenteredOnPoint() {
        let frame = PermissionGuideSourceFrame.around(CGPoint(x: 100, y: 200))

        XCTAssertEqual(frame, CGRect(x: 84, y: 184, width: 32, height: 32))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter PermissionGuidePresentationTests`
Expected: build FAIL with `cannot find 'PermissionGuideThrottle' in scope`.

- [ ] **Step 3: Implement**

`Sources/ZapApp/Models/PermissionGuidePresentation.swift`:

```swift
import AppKit

/// Limits the shortcut-triggered permission guide to one start per app session.
struct PermissionGuideThrottle {
    private var hasStarted = false

    mutating func shouldStart() -> Bool {
        guard !hasStarted else { return false }
        hasStarted = true
        return true
    }
}

/// System Settings renamed the Accessibility privacy page in macOS 27.
enum AccessibilityPaneName {
    static func title(for version: OperatingSystemVersion) -> String {
        version.majorVersion >= 27 ? "Device Control and Data Access" : "Accessibility"
    }

    static var current: String {
        title(for: ProcessInfo.processInfo.operatingSystemVersion)
    }
}

/// Screen-space launch point for the guide panel's fly-in animation.
enum PermissionGuideSourceFrame {
    private static let side: CGFloat = 32

    static func around(_ point: CGPoint) -> CGRect {
        CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
    }

    @MainActor
    static var atMouse: CGRect {
        around(NSEvent.mouseLocation)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter PermissionGuidePresentationTests`
Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ZapApp/Models/PermissionGuidePresentation.swift Tests/ZapAppTests/PermissionGuidePresentationTests.swift
git commit -m "feat: add permission guide presentation helpers"
```

---

### Task 2: PermissionFlow dependency, guide wrapper, and bundling

**Files:**
- Modify: `Package.swift`
- Create: `Sources/ZapApp/Services/AccessibilityPermissionGuide.swift`
- Modify: `Makefile` (`bundle` target after the `ZapMenuBarIcon.png` ditto line; `verify` target)
- Test: `Tests/ZapAppTests/AccessibilityPermissionGuideTests.swift`
- Test: `Tests/ZapAppTests/ReleaseWorkflowTests.swift` (new test method)

**Interfaces:**
- Consumes: `AccessibilityPermissionChecking` (existing, `var isTrusted: Bool`).
- Produces:
  - `@MainActor protocol AccessibilityPermissionGuiding { func start(sourceFrame: CGRect?) }`
  - `@MainActor final class AccessibilityPermissionGuide: AccessibilityPermissionGuiding` with `init(permission: AccessibilityPermissionChecking = AccessibilityPermissionService(), authorize: ((CGRect?) -> Void)? = nil)`

- [ ] **Step 1: Add the dependency**

In `Package.swift`, change `dependencies:` to:

```swift
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.2"),
        .package(url: "https://github.com/jaywcjlove/PermissionFlow", exact: "2.11.2")
    ],
```

and the `ZapApp` target dependencies to:

```swift
            dependencies: [
                "ZapCore",
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "PermissionFlow", package: "PermissionFlow")
            ],
```

Run: `swift package resolve && swift build`
Expected: resolves PermissionFlow 2.11.2, `Package.resolved` updated, build succeeds.

- [ ] **Step 2: Write the failing guide tests**

`Tests/ZapAppTests/AccessibilityPermissionGuideTests.swift`:

```swift
import CoreGraphics
import XCTest
@testable import ZapApp

@MainActor
final class AccessibilityPermissionGuideTests: XCTestCase {
    func testStartAuthorizesWithSourceFrameWhenUntrusted() {
        var authorizedFrames: [CGRect?] = []
        let guide = AccessibilityPermissionGuide(
            permission: StubGuidePermission(isTrusted: false),
            authorize: { authorizedFrames.append($0) }
        )
        let frame = CGRect(x: 10, y: 20, width: 32, height: 32)

        guide.start(sourceFrame: frame)
        guide.start(sourceFrame: nil)

        XCTAssertEqual(authorizedFrames, [frame, nil])
    }

    func testStartDoesNothingWhenAlreadyTrusted() {
        var authorizeCallCount = 0
        let guide = AccessibilityPermissionGuide(
            permission: StubGuidePermission(isTrusted: true),
            authorize: { _ in authorizeCallCount += 1 }
        )

        guide.start(sourceFrame: nil)

        XCTAssertEqual(authorizeCallCount, 0)
    }
}

private struct StubGuidePermission: AccessibilityPermissionChecking {
    let isTrusted: Bool

    func requestPrompt() {}
}
```

(`requestPrompt()` is removed from the protocol in Task 5, which also deletes this stub method.)

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --filter AccessibilityPermissionGuideTests`
Expected: build FAIL with `cannot find 'AccessibilityPermissionGuide' in scope`.

- [ ] **Step 4: Implement the wrapper**

`Sources/ZapApp/Services/AccessibilityPermissionGuide.swift`:

```swift
import AppKit
import PermissionFlow

@MainActor
protocol AccessibilityPermissionGuiding {
    func start(sourceFrame: CGRect?)
}

/// The only PermissionFlow touchpoint: opens the Accessibility pane and shows
/// the drag-to-authorize panel next to System Settings.
@MainActor
final class AccessibilityPermissionGuide: AccessibilityPermissionGuiding {
    private let permission: AccessibilityPermissionChecking
    private let authorizeOverride: ((CGRect?) -> Void)?
    // Lazy so constructing Zap's models does not start PermissionFlow's frontmost-app observers.
    private lazy var controller = PermissionFlow.makeController(
        configuration: .init(
            requiredAppURLs: [Bundle.main.bundleURL],
            promptForAccessibilityTrust: false
        )
    )

    init(
        permission: AccessibilityPermissionChecking = AccessibilityPermissionService(),
        authorize: ((CGRect?) -> Void)? = nil
    ) {
        self.permission = permission
        self.authorizeOverride = authorize
    }

    func start(sourceFrame: CGRect?) {
        guard !permission.isTrusted else { return }

        if let authorizeOverride {
            authorizeOverride(sourceFrame)
            return
        }

        controller.authorize(
            pane: .accessibility,
            suggestedAppURLs: [Bundle.main.bundleURL],
            sourceFrameInScreen: sourceFrame
        )
    }
}
```

- [ ] **Step 5: Run guide tests**

Run: `swift test --filter AccessibilityPermissionGuideTests`
Expected: 2 tests PASS.

- [ ] **Step 6: Write the failing Makefile test**

Add to `Tests/ZapAppTests/ReleaseWorkflowTests.swift`, inside the class, before `private func repositoryRoot()`:

```swift
    func testBundleEmbedsPermissionFlowResources() throws {
        let makefile = try String(contentsOf: repositoryRoot().appendingPathComponent("Makefile"), encoding: .utf8)

        XCTAssertTrue(makefile.contains("PERMISSION_FLOW_BUNDLE := PermissionFlow_PermissionFlow.bundle"))
        XCTAssertTrue(makefile.contains("ditto --norsrc --noextattr \"$$build_dir/$(PERMISSION_FLOW_BUNDLE)\" \"$(RESOURCES_DIR)/$(PERMISSION_FLOW_BUNDLE)\""))
        XCTAssertTrue(makefile.contains("test -d \"$(RESOURCES_DIR)/$(PERMISSION_FLOW_BUNDLE)\""))
    }
```

Run: `swift test --filter ReleaseWorkflowTests/testBundleEmbedsPermissionFlowResources`
Expected: FAIL (assertions false).

- [ ] **Step 7: Update the Makefile**

Add the variable next to `RESOURCES_DIR := $(CONTENTS_DIR)/Resources` (line ~38):

```make
PERMISSION_FLOW_BUNDLE := PermissionFlow_PermissionFlow.bundle
```

In the `bundle` target, the first recipe line block already defines `build_dir` in one shell invocation; `build_dir` is not available in later recipe lines. Add a new recipe line right after `ditto --norsrc --noextattr "$(MENU_BAR_ICON_FILE)" "$(RESOURCES_DIR)/ZapMenuBarIcon.png"`:

```make
	build_dir="$$(swift build -c "$(CONFIGURATION)" --show-bin-path)"; \
	test -d "$$build_dir/$(PERMISSION_FLOW_BUNDLE)" || { echo "Missing $(PERMISSION_FLOW_BUNDLE) under $$build_dir"; exit 1; }; \
	rm -rf "$(RESOURCES_DIR)/$(PERMISSION_FLOW_BUNDLE)"; \
	ditto --norsrc --noextattr "$$build_dir/$(PERMISSION_FLOW_BUNDLE)" "$(RESOURCES_DIR)/$(PERMISSION_FLOW_BUNDLE)"
```

In the `verify` target, add after `test -f "$(RESOURCES_DIR)/ZapMenuBarIcon.png"`:

```make
	test -d "$(RESOURCES_DIR)/$(PERMISSION_FLOW_BUNDLE)"
```

- [ ] **Step 8: Verify tests and the real bundle**

Run: `swift test --filter ReleaseWorkflowTests`
Expected: PASS.

Run: `make dev-verify`
Expected: ends with `verification passed`; `codesign --verify --strict` passes with the resource bundle inside. If signing fails because of the bundle (e.g. "unsealed contents"), stop and report — do not add `--deep` signing without discussion.

Run: `ls "/tmp/zap-bundles/dev/Zap dev.app/Contents/Resources/"`
Expected: lists `PermissionFlow_PermissionFlow.bundle`.

- [ ] **Step 9: Commit**

```bash
git add Package.swift Package.resolved Sources/ZapApp/Services/AccessibilityPermissionGuide.swift Makefile Tests/ZapAppTests/AccessibilityPermissionGuideTests.swift Tests/ZapAppTests/ReleaseWorkflowTests.swift
git commit -m "feat: add PermissionFlow-backed accessibility guide"
```

---

### Task 3: Wire the guide into `WindowManagementModel`

**Files:**
- Modify: `Sources/ZapApp/ViewModels/WindowManagementModel.swift` (init ~L38-58, `perform(action:)` ~L64-74, `requestAccessibilityPermission()` ~L117-119)
- Test: `Tests/ZapAppTests/WindowManagementModelTests.swift`

**Interfaces:**
- Consumes: `AccessibilityPermissionGuiding.start(sourceFrame:)`, `AccessibilityPermissionGuide(permission:)`, `PermissionGuideThrottle.shouldStart()`.
- Produces: `WindowManagementModel.init(..., permissionGuide: AccessibilityPermissionGuiding? = nil, ...)`, `func requestAccessibilityPermission(sourceFrame: CGRect? = nil)`.

- [ ] **Step 1: Write the failing tests**

In `WindowManagementModelTests.swift`:

Add a fake at the bottom of the file:

```swift
@MainActor
private final class FakePermissionGuide: AccessibilityPermissionGuiding {
    var startedFrames: [CGRect?] = []

    func start(sourceFrame: CGRect?) {
        startedFrames.append(sourceFrame)
    }
}
```

Change `makeModel` to accept and pass the guide:

```swift
    private func makeModel(
        service: FakeWindowActionPerformer = FakeWindowActionPerformer(),
        permission: FakeAccessibilityPermission = FakeAccessibilityPermission(isTrusted: true),
        permissionGuide: FakePermissionGuide = FakePermissionGuide(),
        settingsOpener: FakeSystemSettingsOpener = FakeSystemSettingsOpener(),
        shortcuts: [WindowShortcut] = WindowShortcutDefaults.all,
        isEnabled: Bool = true
    ) -> WindowManagementModel {
        WindowManagementModel(
            service: service,
            permissionService: permission,
            permissionGuide: permissionGuide,
            settingsOpener: settingsOpener,
            shortcutStore: InMemoryWindowShortcutStore(shortcuts: shortcuts),
            isWindowManagementEnabled: isEnabled
        )
    }
```

Replace `testPermissionButtonsRequestPromptRefreshStateAndOpenSettings` with:

```swift
    func testPermissionButtonsStartGuideRefreshStateAndOpenSettings() {
        let permission = FakeAccessibilityPermission(isTrusted: false)
        let guide = FakePermissionGuide()
        let opener = FakeSystemSettingsOpener()
        let model = makeModel(permission: permission, permissionGuide: guide, settingsOpener: opener)
        let frame = CGRect(x: 1, y: 2, width: 32, height: 32)

        XCTAssertFalse(model.accessibilityTrusted)

        model.requestAccessibilityPermission(sourceFrame: frame)
        model.requestAccessibilityPermission(sourceFrame: frame)
        XCTAssertEqual(guide.startedFrames, [frame, frame])
        XCTAssertEqual(permission.requestPromptCallCount, 0)

        permission.trusted = true
        model.refreshAccessibilityPermission()
        XCTAssertTrue(model.accessibilityTrusted)

        model.openAccessibilitySettings()
        XCTAssertEqual(opener.openSettingsCallCount, 1)
    }

    func testMissingPermissionStartsGuideOncePerSession() {
        let service = FakeWindowActionPerformer(result: .failure(.accessibilityPermissionMissing))
        let guide = FakePermissionGuide()
        let model = makeModel(service: service, permissionGuide: guide)

        _ = model.perform(action: .leftHalf)
        _ = model.perform(action: .rightHalf)
        _ = model.perform(action: .center)

        XCTAssertEqual(guide.startedFrames, [nil])
    }

    func testOtherFailuresDoNotStartGuide() {
        let service = FakeWindowActionPerformer(result: .failure(.focusedWindowMissing))
        let guide = FakePermissionGuide()
        let model = makeModel(service: service, permissionGuide: guide)

        _ = model.perform(action: .center)

        XCTAssertTrue(guide.startedFrames.isEmpty)
    }

    func testButtonGuideDoesNotConsumeShortcutThrottle() {
        let service = FakeWindowActionPerformer(result: .failure(.accessibilityPermissionMissing))
        let guide = FakePermissionGuide()
        let model = makeModel(service: service, permission: FakeAccessibilityPermission(isTrusted: false), permissionGuide: guide)

        model.requestAccessibilityPermission()
        _ = model.perform(action: .leftHalf)

        XCTAssertEqual(guide.startedFrames, [nil, nil])
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter WindowManagementModelTests`
Expected: build FAIL — `extra argument 'permissionGuide' in call`.

- [ ] **Step 3: Implement**

In `WindowManagementModel.swift`:

Add stored properties after `private let permissionService: AccessibilityPermissionChecking`:

```swift
    private let permissionGuide: AccessibilityPermissionGuiding
    private var shortcutGuideThrottle = PermissionGuideThrottle()
```

Change the init signature and body (add the parameter after `permissionService`):

```swift
    init(
        service: WindowActionPerforming = WindowManagementService(history: DefaultWindowHistoryRecorder()),
        permissionService: AccessibilityPermissionChecking = AccessibilityPermissionService(),
        permissionGuide: AccessibilityPermissionGuiding? = nil,
        settingsOpener: SystemSettingsOpening = SystemSettingsOpener(),
        shortcutStore: WindowShortcutStoring = UserDefaultsWindowShortcutStore(),
        settingsStore: WindowManagementSettingsStoring = UserDefaultsWindowManagementSettingsStore(),
        isWindowManagementEnabled: Bool? = nil
    ) {
        self.service = service
        self.permissionService = permissionService
        self.permissionGuide = permissionGuide ?? AccessibilityPermissionGuide(permission: permissionService)
        // ...rest unchanged
```

Replace `perform(action:)`:

```swift
    @discardableResult
    func perform(action: WindowAction) -> WindowManagementResult {
        let result = service.perform(action: action)
        switch result {
        case .success:
            windowManagementError = nil
        case let .failure(error):
            windowManagementError = String(describing: error)
            if case .accessibilityPermissionMissing = error, shortcutGuideThrottle.shouldStart() {
                permissionGuide.start(sourceFrame: nil)
            }
        }
        return result
    }
```

Replace `requestAccessibilityPermission()`:

```swift
    func requestAccessibilityPermission(sourceFrame: CGRect? = nil) {
        permissionGuide.start(sourceFrame: sourceFrame)
    }
```

(`case accessibilityPermissionMissing` in `Sources/ZapApp/Services/WindowManagementService.swift:11` has no payload, so `if case .accessibilityPermissionMissing = error` compiles.)

- [ ] **Step 4: Run tests**

Run: `swift test --filter WindowManagementModelTests`
Expected: all PASS.

Run: `swift test`
Expected: all PASS (`SettingsWindowManagementUITests` still passes because SettingsView is unchanged and calls `requestAccessibilityPermission()` with the default argument).

- [ ] **Step 5: Commit**

```bash
git add Sources/ZapApp/ViewModels/WindowManagementModel.swift Tests/ZapAppTests/WindowManagementModelTests.swift
git commit -m "feat: start accessibility guide from settings and missing-permission shortcuts"
```

---

### Task 4: Settings Permissions row UI

**Files:**
- Modify: `Sources/ZapApp/Views/SettingsView.swift:197-223` (`permissionsSection`)
- Test: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift:122-138` (`testGeneralSectionOwnsPermissionsBehaviorAndUpdates`)

**Interfaces:**
- Consumes: `AccessibilityPaneName.current`, `PermissionGuideSourceFrame.atMouse`, `WindowManagementModel.requestAccessibilityPermission(sourceFrame:)`.
- Produces: nothing new.

- [ ] **Step 1: Update the source-inspection test (failing)**

In `testGeneralSectionOwnsPermissionsBehaviorAndUpdates`, replace these three lines:

```swift
        XCTAssertTrue(source.contains("Accessibility"))
        XCTAssertTrue(source.contains("Button(\"Request\")"))
        XCTAssertTrue(source.contains("model.windowManagementModel.requestAccessibilityPermission()\n                            refreshAccessibilityPermission()"))
```

with:

```swift
        XCTAssertTrue(source.contains("title: AccessibilityPaneName.current"))
        XCTAssertTrue(source.contains("Drag Zap into the list to let it move and resize windows."))
        XCTAssertTrue(source.contains("Button(\"Grant…\")"))
        XCTAssertFalse(source.contains("Button(\"Request\")"))
        XCTAssertTrue(source.contains("model.windowManagementModel.requestAccessibilityPermission(\n                                sourceFrame: PermissionGuideSourceFrame.atMouse\n                            )\n                            refreshAccessibilityPermission()"))
```

Run: `swift test --filter SettingsWindowManagementUITests`
Expected: FAIL.

- [ ] **Step 2: Update the view**

In `permissionsSection`, change the `SettingsRow` arguments:

```swift
            SettingsRow(
                title: AccessibilityPaneName.current,
                subtitle: "Drag Zap into the list to let it move and resize windows.",
```

and replace the `Button("Request") { ... }` block with:

```swift
                        Button("Grant…") {
                            model.windowManagementModel.requestAccessibilityPermission(
                                sourceFrame: PermissionGuideSourceFrame.atMouse
                            )
                            refreshAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
```

(`SettingsRow.title` is `String` — `Sources/ZapApp/Views/ZapDesignSystem.swift:40` — so `AccessibilityPaneName.current` passes directly.)

- [ ] **Step 3: Run tests**

Run: `swift test --filter SettingsWindowManagementUITests`
Expected: PASS.

Run: `swift test`
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/ZapApp/Views/SettingsView.swift Tests/ZapAppTests/SettingsWindowManagementUITests.swift
git commit -m "feat: show drag-to-grant accessibility row in settings"
```

---

### Task 5: Remove the unused AX prompt API

**Files:**
- Modify: `Sources/ZapApp/Services/AccessibilityPermissionService.swift`
- Modify: `Tests/ZapAppTests/AccessibilityPermissionServiceTests.swift`
- Modify: `Tests/ZapAppTests/WindowManagementModelTests.swift` (`FakeAccessibilityPermission`, `testPermissionButtonsStartGuideRefreshStateAndOpenSettings`)
- Modify: `Tests/ZapAppTests/ShortcutHUDScreenResolverTests.swift` (`StubHUDPermission`, line ~48 assertion)
- Modify: `Tests/ZapAppTests/WindowManagementServiceTests.swift:440`
- Modify: `Tests/ZapAppTests/AccessibilityPermissionGuideTests.swift` (`StubGuidePermission`)

**Interfaces:**
- Consumes: nothing.
- Produces: `protocol AccessibilityPermissionChecking { var isTrusted: Bool { get } }` (no `requestPrompt`); `protocol AXPermissionClienting { var isTrusted: Bool { get } }`.

- [ ] **Step 1: Confirm no production callers**

Run: `grep -rn "requestPrompt" Sources`
Expected: only the declarations/implementations in `AccessibilityPermissionService.swift`.

- [ ] **Step 2: Shrink the service**

Replace `Sources/ZapApp/Services/AccessibilityPermissionService.swift` with:

```swift
import ApplicationServices

protocol AccessibilityPermissionChecking {
    var isTrusted: Bool { get }
}

protocol AXPermissionClienting {
    var isTrusted: Bool { get }
}

struct AccessibilityPermissionService: AccessibilityPermissionChecking {
    private let client: AXPermissionClienting

    init(client: AXPermissionClienting = AXPermissionClient()) {
        self.client = client
    }

    var isTrusted: Bool {
        client.isTrusted
    }
}

struct AXPermissionClient: AXPermissionClienting {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }
}
```

- [ ] **Step 3: Update test doubles**

- `AccessibilityPermissionServiceTests.swift`: delete `testRequestPromptAsksAXClientToShowPrompt`; in `MockAXPermissionClient` delete `requestedPromptValues` and `requestPrompt(showPrompt:)`.
- `WindowManagementModelTests.swift`: in `FakeAccessibilityPermission` delete `requestPromptCallCount` and `requestPrompt()`; in `testPermissionButtonsStartGuideRefreshStateAndOpenSettings` delete `XCTAssertEqual(permission.requestPromptCallCount, 0)`.
- `ShortcutHUDScreenResolverTests.swift`: in `StubHUDPermission` delete `requestPromptCallCount` and `requestPrompt()`; delete `XCTAssertEqual(permission.requestPromptCallCount, 0)` in `testUntrustedAccessibilitySkipsAXAndUsesMouseDisplay`.
- `WindowManagementServiceTests.swift`: delete `func requestPrompt() {}` (~line 440).
- `AccessibilityPermissionGuideTests.swift`: delete `func requestPrompt() {}` from `StubGuidePermission`.

- [ ] **Step 4: Run all tests**

Run: `grep -rn "requestPrompt" Sources Tests`
Expected: no output.

Run: `swift test`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ZapApp/Services/AccessibilityPermissionService.swift Tests/ZapAppTests
git commit -m "refactor: drop unused accessibility prompt API"
```

---

### Task 6: Manual verification in the built app

**Files:** none (report results; fix-forward in the owning task's files if something fails).

- [ ] **Step 1: Build and run the dev app**

Run: `make dev-verify && make dev-run`
Expected: `verification passed`, Zap (dev) launches.

- [ ] **Step 2: Reset the permission**

In System Settings > Privacy & Security > Device Control and Data Access (Accessibility on < 27), remove the dev Zap entry with `−`. Alternatively: `tccutil reset Accessibility com.woosublee.zap.dev`. Relaunch the dev app.

- [ ] **Step 3: Button path**

Open Zap Settings > General. Expected: row title `Device Control and Data Access` (macOS 27), subtitle `Drag Zap into the list…`, button `Grant…`. Click it. Expected: System Settings opens on the pane, a panel flies from the click point and docks beside the Settings window, moving the Settings window drags the panel along, the panel shows the Zap icon; dragging it into the list adds Zap; toggling it on and returning to Zap shows `Granted`.

- [ ] **Step 4: Shortcut path**

Reset the permission again (Step 2) and relaunch. Press a window shortcut (default `⌥⌘←`) three times. Expected: the guide appears once; the next presses only beep. Close System Settings without dragging. Expected: the panel closes.

- [ ] **Step 5: Localized panel strings**

With the panel open, confirm its text is localized (e.g. Korean on a Korean system), not raw keys like `permission_flow.…`. Raw keys mean the resource bundle was not found — revisit Task 2 Step 7/8.

- [ ] **Step 6: Report**

Summarize each step's result (pass/fail with what was seen). No commit unless fixes were made.
