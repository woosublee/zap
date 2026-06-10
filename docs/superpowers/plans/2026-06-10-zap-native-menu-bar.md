# Zap Native Menu Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert Zap's menu bar UI to a native macOS submenu structure, move About into Settings, and keep existing launch/window actions working.

**Architecture:** Replace the current custom `.window` `MenuBarExtra` panel with a `.menu` style menu built from SwiftUI `Menu`, `Button`, and `Divider`. `MenuBarView` becomes a thin command menu that delegates actions to existing `ZapAppModel`, `WindowManagementModel`, and `UpdateService`; Settings gains a focused `.about` mode that reuses `AboutView` and `AboutPresentation`.

**Tech Stack:** Swift 5.10, SwiftUI, AppKit, Swift Package Manager, XCTest source/compile tests.

---

## File Structure

- Modify: `Tests/ZapAppTests/MenuBarViewTests.swift`
  - Owns source-level expectations for the menu bar structure.
  - Replace tests that assumed the custom status/header panel with tests for native `Menu` submenus and removed About/status dependencies.

- Modify: `Sources/ZapApp/Views/MenuBarView.swift`
  - Replace custom panel rows with native menu content.
  - Keep action wiring only: Quick Launch, Window Control, Refresh Dock Apps, Check for Updates, Settings, Quit.

- Modify: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`
  - Update existing Settings mode/sidebar expectations for `.about`.
  - Remove stale assertion that ZapApp opens Settings directly to Window Management from the menu bar.
  - Add Settings About routing/source expectations.

- Modify: `Sources/ZapApp/Views/SettingsView.swift`
  - Add `SettingsMode.about`.
  - Add About to the System sidebar group.
  - Render an About settings panel using existing `AboutView`.

- Modify: `Sources/ZapApp/ZapApp.swift`
  - Change `MenuBarExtra` style from `.window` to `.menu`.
  - Remove `openWindowManagementSettings` and `openAbout` wiring from `MenuBarView` construction.
  - Remove the now-unused private `openAbout()` method.

- Verify only: `Sources/ZapApp/Services/AboutWindowPresenter.swift`
  - Do not delete. It remains available for tests or future app-menu use.

---

### Task 1: Update menu bar tests for native submenu expectations

**Files:**
- Modify: `Tests/ZapAppTests/MenuBarViewTests.swift`

- [ ] **Step 1: Replace `MenuBarViewTests.swift` with native menu expectations**

Replace the entire file with:

```swift
import XCTest

final class MenuBarViewTests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var menuBarSource: String {
        get throws {
            try String(contentsOf: packageRootURL
                .appendingPathComponent("Sources/ZapApp/Views/MenuBarView.swift"))
        }
    }

    private var appSource: String {
        get throws {
            try String(contentsOf: packageRootURL
                .appendingPathComponent("Sources/ZapApp/ZapApp.swift"))
        }
    }

    func testMenuBarUsesNativeQuickLaunchAndWindowControlSubmenus() throws {
        let source = try menuBarSource

        XCTAssertTrue(source.contains("Menu(\"Quick Launch\")"))
        XCTAssertTrue(source.contains("Menu(\"Window Control\")"))
        XCTAssertTrue(source.contains("Button(\"Refresh Dock Apps\")"))
        XCTAssertTrue(source.contains("Button(\"Check for Updates...\")"))
        XCTAssertTrue(source.contains("Button(\"Settings...\")"))
        XCTAssertTrue(source.contains("Button(\"Quit \\(AboutPresentation.currentAppName)\")"))
    }

    func testMenuBarQuickLaunchSubmenuKeepsFinderManualAndDockActions() throws {
        let source = try menuBarSource

        XCTAssertTrue(source.contains("model.isFinderShortcutEnabled"))
        XCTAssertTrue(source.contains("model.activateFinder()"))
        XCTAssertTrue(source.contains("model.activeManualShortcuts"))
        XCTAssertTrue(source.contains("model.activateManualShortcut(id: shortcut.id)"))
        XCTAssertTrue(source.contains("NumberKey.allCases"))
        XCTAssertTrue(source.contains("if let item = model.dockItem(for: key)"))
        XCTAssertTrue(source.contains("model.activateDockItem(for: key)"))
        XCTAssertFalse(source.contains("Dock slot \\(key.rawValue)"))
    }

    func testMenuBarWindowControlSubmenuListsConfiguredWindowShortcuts() throws {
        let source = try menuBarSource

        XCTAssertTrue(source.contains("WindowActionCategory.allCases"))
        XCTAssertTrue(source.contains("model.windowManagementModel.windowShortcuts"))
        XCTAssertTrue(source.contains("WindowShortcutDisplay.shortcutTitle(for: shortcut)"))
        XCTAssertTrue(source.contains("model.windowManagementModel.perform(action: shortcut.action)"))
        XCTAssertTrue(source.contains("Divider()"))
        XCTAssertFalse(source.contains("Window Shortcuts..."))
        XCTAssertFalse(source.contains("openWindowManagementSettings"))
    }

    func testMenuBarRemovesStatusAndAboutRows() throws {
        let source = try menuBarSource

        XCTAssertFalse(source.contains("sectionLabel(\"Status\")"))
        XCTAssertFalse(source.contains("StatusRow"))
        XCTAssertFalse(source.contains("Accessibility"))
        XCTAssertFalse(source.contains("Needs Permission"))
        XCTAssertFalse(source.contains("Ready"))
        XCTAssertFalse(source.contains("registrationError"))
        XCTAssertFalse(source.contains("windowManagementError"))
        XCTAssertFalse(source.contains("AboutPresentation.aboutMenuLabel"))
        XCTAssertFalse(source.contains("openAbout"))
    }

    func testMenuBarNoLongerUsesCustomWindowPanelRows() throws {
        let source = try menuBarSource

        XCTAssertFalse(source.contains("private var header"))
        XCTAssertFalse(source.contains("private struct MenuRow"))
        XCTAssertFalse(source.contains("ShortcutKeycapGroupView"))
        XCTAssertFalse(source.contains("NSApp.applicationIconImage"))
        XCTAssertFalse(source.contains("frame(width: 340)"))
    }

    func testZapAppUsesMenuStyleMenuBarExtra() throws {
        let source = try appSource

        XCTAssertTrue(source.contains(".menuBarExtraStyle(.menu)"))
        XCTAssertFalse(source.contains(".menuBarExtraStyle(.window)"))
        XCTAssertFalse(source.contains("openWindowManagementSettings:"))
        XCTAssertFalse(source.contains("openAbout:"))
        XCTAssertFalse(source.contains("private func openAbout()"))
    }
}
```

- [ ] **Step 2: Run the updated menu bar tests and verify they fail**

Run:

```bash
swift test --filter MenuBarViewTests
```

Expected: FAIL. At least these assertions should fail before implementation:

- `source.contains("Menu(\"Quick Launch\")")`
- `source.contains("Menu(\"Window Control\")")`
- `source.contains(".menuBarExtraStyle(.menu)")`
- `XCTAssertFalse(source.contains("StatusRow"))`

- [ ] **Step 3: Checkpoint**

Do not commit unless the user explicitly authorizes commits. If commits are authorized, use:

```bash
git add Tests/ZapAppTests/MenuBarViewTests.swift
git commit -m "test: expect native menu bar submenus"
```

---

### Task 2: Implement native menu bar content

**Files:**
- Modify: `Sources/ZapApp/Views/MenuBarView.swift`
- Modify: `Sources/ZapApp/ZapApp.swift`
- Test: `Tests/ZapAppTests/MenuBarViewTests.swift`

- [ ] **Step 1: Replace `MenuBarView.swift` with native menu content**

Replace the entire file with:

```swift
import SwiftUI
import ZapCore

struct MenuBarView: View {
    @ObservedObject var model: ZapAppModel
    @ObservedObject var updateService: UpdateService
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        quickLaunchMenu
        windowControlMenu

        Divider()

        Button("Refresh Dock Apps") {
            model.refreshDockItems()
        }
        Button("Check for Updates...") {
            updateService.checkForUpdates()
        }

        Divider()

        Button("Settings...") {
            openSettings()
        }
        Button("Quit \(AboutPresentation.currentAppName)") {
            quit()
        }
    }

    private var quickLaunchMenu: some View {
        Menu("Quick Launch") {
            if model.isFinderShortcutEnabled {
                Button(menuLabel("Finder", shortcut: model.finderShortcutTitle)) {
                    model.activateFinder()
                }

                if hasQuickLaunchItemsAfterFinder {
                    Divider()
                }
            }

            ForEach(model.activeManualShortcuts) { shortcut in
                Button(menuLabel(shortcut.name, shortcut: shortcut.shortcutTitle)) {
                    model.activateManualShortcut(id: shortcut.id)
                }
            }

            if !model.activeManualShortcuts.isEmpty && hasDockItems {
                Divider()
            }

            ForEach(NumberKey.allCases) { key in
                if let item = model.dockItem(for: key) {
                    Button(menuLabel(item.name, shortcut: model.shortcutTitle(for: key))) {
                        model.activateDockItem(for: key)
                    }
                }
            }
        }
    }

    private var windowControlMenu: some View {
        Menu("Window Control") {
            ForEach(WindowActionCategory.allCases, id: \.self) { category in
                windowShortcutButtons(for: category)

                if category != WindowActionCategory.allCases.last {
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func windowShortcutButtons(for category: WindowActionCategory) -> some View {
        ForEach(windowShortcuts(for: category)) { shortcut in
            Button(menuLabel(
                shortcut.action.displayName,
                shortcut: WindowShortcutDisplay.shortcutTitle(for: shortcut)
            )) {
                _ = model.windowManagementModel.perform(action: shortcut.action)
            }
        }
    }

    private var hasQuickLaunchItemsAfterFinder: Bool {
        !model.activeManualShortcuts.isEmpty || hasDockItems
    }

    private var hasDockItems: Bool {
        NumberKey.allCases.contains { key in
            model.dockItem(for: key) != nil
        }
    }

    private func windowShortcuts(for category: WindowActionCategory) -> [WindowShortcut] {
        model.windowManagementModel.windowShortcuts.filter { shortcut in
            shortcut.action.category == category
        }
    }

    private func menuLabel(_ title: String, shortcut: String?) -> String {
        guard let shortcut, !shortcut.isEmpty else { return title }
        return "\(title)    \(shortcut)"
    }
}
```

Implementation notes:

- The menu label appends shortcut text as plain text. Do not use `.keyboardShortcut` because global hotkeys are already registered separately.
- Keep Dock slot filtering with `if let item = model.dockItem(for: key)` so empty Dock slots remain hidden.
- Keep Window Control visible even if Accessibility permission is missing. Existing `WindowManagementModel.perform(action:)` records failures.

- [ ] **Step 2: Update `ZapApp.swift` menu construction**

In `Sources/ZapApp/ZapApp.swift`, replace the `MenuBarView` construction and menu style block:

```swift
MenuBarExtra(isInserted: $showMenuBarIcon) {
    MenuBarView(
        model: model,
        updateService: updateService,
        openSettings: { openSettings() },
        openWindowManagementSettings: { openSettings(initialMode: .windowManagement) },
        openAbout: { openAbout() },
        quit: { NSApp.terminate(nil) }
    )
} label: {
    menuBarIcon
}
.menuBarExtraStyle(.window)
```

with:

```swift
MenuBarExtra(isInserted: $showMenuBarIcon) {
    MenuBarView(
        model: model,
        updateService: updateService,
        openSettings: { openSettings() },
        quit: { NSApp.terminate(nil) }
    )
} label: {
    menuBarIcon
}
.menuBarExtraStyle(.menu)
```

Then remove this now-unused method from the same file:

```swift
private func openAbout() {
    AboutWindowPresenter.open()
}
```

- [ ] **Step 3: Run menu bar tests and verify they pass**

Run:

```bash
swift test --filter MenuBarViewTests
```

Expected: PASS.

- [ ] **Step 4: Run a compile check for ZapApp target**

Run:

```bash
swift build -c debug --product Zap
```

Expected: build completes without Swift compile errors.

- [ ] **Step 5: Checkpoint**

Do not commit unless the user explicitly authorizes commits. If commits are authorized, use:

```bash
git add Sources/ZapApp/Views/MenuBarView.swift Sources/ZapApp/ZapApp.swift Tests/ZapAppTests/MenuBarViewTests.swift
git commit -m "feat: convert menu bar to native submenus"
```

---

### Task 3: Add Settings About mode tests

**Files:**
- Modify: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`

- [ ] **Step 1: Update Settings mode title expectations**

In `testSettingsModeIncludesShortcutModesAndSetting`, replace:

```swift
XCTAssertEqual(SettingsMode.allCases.map(\.title), [
    "Automatic",
    "Manual",
    "Window Management",
    "Setting"
])
```

with:

```swift
XCTAssertEqual(SettingsMode.allCases.map(\.title), [
    "Automatic",
    "Manual",
    "Window Management",
    "Setting",
    "About"
])
```

- [ ] **Step 2: Update sidebar grouping expectations**

In `testSettingsSidebarGroupsShortcutModesAndSystemSetting`, replace the method body with:

```swift
let source = try String(contentsOf: packageRootURL
    .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

XCTAssertTrue(source.contains("sidebarSection(title: \"Shortcuts\", modes: [.automatic, .manual, .windowManagement])"))
XCTAssertTrue(source.contains("sidebarSection(title: \"System\", modes: [.setting, .about])"))
XCTAssertTrue(source.contains("case .setting:"))
XCTAssertTrue(source.contains("case .about:"))
XCTAssertTrue(source.contains("settingSection"))
XCTAssertTrue(source.contains("aboutSection"))
```

- [ ] **Step 3: Remove stale direct Window Management app-menu assertion**

In `testSettingsWindowCanOpenDirectlyToWindowManagementMode`, replace the method body with:

```swift
let presenterSource = try String(contentsOf: packageRootURL
    .appendingPathComponent("Sources/ZapApp/Services/SettingsWindowPresenter.swift"))
let settingsSource = try String(contentsOf: packageRootURL
    .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

XCTAssertTrue(settingsSource.contains("initialMode: SettingsMode = .automatic"))
XCTAssertTrue(settingsSource.contains("_selectedMode = State(initialValue: initialMode)"))
XCTAssertTrue(presenterSource.contains("initialMode: SettingsMode = .automatic"))
XCTAssertTrue(presenterSource.contains("initialMode: initialMode"))
```

- [ ] **Step 4: Add a focused About routing test**

Add this test method near the other Settings sidebar tests:

```swift
func testSettingsAboutModeRendersExistingAboutViewWithoutExtraCardWrapper() throws {
    let source = try String(contentsOf: packageRootURL
        .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

    XCTAssertTrue(source.contains("case .about:"))
    XCTAssertTrue(source.contains("aboutSection"))
    XCTAssertTrue(source.contains("AboutView(presentation: AboutPresentation(appName: AboutPresentation.currentAppName, info: AboutInfo.current))"))
    XCTAssertFalse(source.contains("SettingsCard(title: AboutPresentation.aboutMenuLabel(appName: AboutPresentation.currentAppName))"))
    XCTAssertTrue(source.contains("case .about: \"About\""))
    XCTAssertTrue(source.contains("case .about: \"info.circle\""))
}

func testSettingsContentDoesNotRenderPerModeHeader() throws {
    let source = try String(contentsOf: packageRootURL
        .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

    XCTAssertFalse(source.contains("settingsHeader"))
    XCTAssertFalse(source.contains("Text(selectedMode.title)"))
    XCTAssertFalse(source.contains("selectedMode.subtitle"))
}
```

- [ ] **Step 5: Run the updated Settings tests and verify they fail**

Run:

```bash
swift test --filter SettingsWindowManagementUITests/testSettingsModeIncludesShortcutModesAndSetting
swift test --filter SettingsWindowManagementUITests/testSettingsSidebarGroupsShortcutModesAndSystemSetting
swift test --filter SettingsWindowManagementUITests/testSettingsAboutModeRendersExistingAboutViewWithoutExtraCardWrapper
swift test --filter SettingsWindowManagementUITests/testSettingsContentDoesNotRenderPerModeHeader
```

Expected: FAIL before implementation because `.about`, `aboutSection`, the AboutView routing, the direct About rendering, or the header removal do not exist yet.

- [ ] **Step 6: Checkpoint**

Do not commit unless the user explicitly authorizes commits. If commits are authorized, use:

```bash
git add Tests/ZapAppTests/SettingsWindowManagementUITests.swift
git commit -m "test: expect about section in settings"
```

---

### Task 4: Implement Settings About mode

**Files:**
- Modify: `Sources/ZapApp/Views/SettingsView.swift`
- Test: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`

- [ ] **Step 1: Route `.about` in the Settings content switch**

In `SettingsView.body`, update the `switch selectedMode` block from:

```swift
switch selectedMode {
case .automatic:
    automaticShortcutsSection
    automaticSection
case .manual:
    manualSection
case .windowManagement:
    WindowManagementSettingsView(
        model: model.windowManagementModel,
        registrationError: model.registrationError,
        inputSourceRevision: model.inputSourceRevision
    )
case .setting:
    settingSection
}
```

To:

```swift
switch selectedMode {
case .automatic:
    automaticShortcutsSection
    automaticSection
case .manual:
    manualSection
case .windowManagement:
    WindowManagementSettingsView(
        model: model.windowManagementModel,
        registrationError: model.registrationError,
        inputSourceRevision: model.inputSourceRevision
    )
case .setting:
    settingSection
case .about:
    aboutSection
}
```

- [ ] **Step 2: Add About to the System sidebar group**

Replace:

```swift
sidebarSection(title: "System", modes: [.setting])
    .padding(.top, 10)
```

with:

```swift
sidebarSection(title: "System", modes: [.setting, .about])
    .padding(.top, 10)
```

- [ ] **Step 3: Add `aboutSection` near `settingSection`**

Insert this property after `settingSection`:

```swift
private var aboutSection: some View {
    HStack {
        Spacer(minLength: 0)
        AboutView(presentation: AboutPresentation(appName: AboutPresentation.currentAppName, info: AboutInfo.current))
        Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity)
}
```

- [ ] **Step 4: Add `.about` to `SettingsMode`**

Update the enum cases from:

```swift
enum SettingsMode: String, CaseIterable, Identifiable {
    case automatic
    case manual
    case windowManagement
    case setting
```

To:

```swift
enum SettingsMode: String, CaseIterable, Identifiable {
    case automatic
    case manual
    case windowManagement
    case setting
    case about
```

Then update `title` from:

```swift
switch self {
case .automatic: "Automatic"
case .manual: "Manual"
case .windowManagement: "Window Management"
case .setting: "Setting"
}
```

To:

```swift
switch self {
case .automatic: "Automatic"
case .manual: "Manual"
case .windowManagement: "Window Management"
case .setting: "Setting"
case .about: "About"
}
```

Remove the now-unused `subtitle` computed property from `SettingsMode`; the Settings content area no longer renders per-mode title/subtitle headers.

Then update `systemImage` from:

```swift
switch self {
case .automatic: "sparkle"
case .manual: "keyboard"
case .windowManagement: "rectangle.3.group"
case .setting: "gearshape"
}
```

To:

```swift
switch self {
case .automatic: "sparkle"
case .manual: "keyboard"
case .windowManagement: "rectangle.3.group"
case .setting: "gearshape"
case .about: "info.circle"
}
```

- [ ] **Step 5: Run the Settings tests and verify they pass**

Run:

```bash
swift test --filter SettingsWindowManagementUITests/testSettingsModeIncludesShortcutModesAndSetting
swift test --filter SettingsWindowManagementUITests/testSettingsSidebarGroupsShortcutModesAndSystemSetting
swift test --filter SettingsWindowManagementUITests/testSettingsAboutModeRendersExistingAboutViewWithoutExtraCardWrapper
swift test --filter SettingsWindowManagementUITests/testSettingsContentDoesNotRenderPerModeHeader
swift test --filter SettingsWindowManagementUITests/testSettingsWindowCanOpenDirectlyToWindowManagementMode
```

Expected: PASS.

- [ ] **Step 6: Run a compile check for SettingsView**

Run:

```bash
swift build -c debug --product Zap
```

Expected: build completes without Swift compile errors.

- [ ] **Step 7: Checkpoint**

Do not commit unless the user explicitly authorizes commits. If commits are authorized, use:

```bash
git add Sources/ZapApp/Views/SettingsView.swift Tests/ZapAppTests/SettingsWindowManagementUITests.swift
git commit -m "feat: move about into settings"
```

---

### Task 5: Full verification and development app launch

**Files:**
- Verify: all modified files

- [ ] **Step 1: Run the full test suite**

Run:

```bash
swift test
```

Expected: PASS with zero failing tests.

- [ ] **Step 2: Build and launch the development app**

Run:

```bash
make dev-run
```

Expected: command exits successfully after opening `/tmp/zap-bundles/dev/Zap dev.app`.

- [ ] **Step 3: Verify the development app is running**

Run:

```bash
osascript -e 'application id "com.woosublee.zap.dev" is running'
```

Expected output:

```text
true
```

- [ ] **Step 4: Verify the development bundle code signature**

Run:

```bash
codesign --verify --strict --verbose=2 "/tmp/zap-bundles/dev/Zap dev.app"
```

Expected output includes:

```text
/tmp/zap-bundles/dev/Zap dev.app: valid on disk
/tmp/zap-bundles/dev/Zap dev.app: satisfies its Designated Requirement
```

- [ ] **Step 5: Inspect the final diff**

Run:

```bash
git diff -- Sources/ZapApp/Views/MenuBarView.swift Sources/ZapApp/ZapApp.swift Sources/ZapApp/Views/SettingsView.swift Tests/ZapAppTests/MenuBarViewTests.swift Tests/ZapAppTests/SettingsWindowManagementUITests.swift
```

Expected:

- `MenuBarView` uses `Menu("Quick Launch")` and `Menu("Window Control")`.
- `MenuBarView` does not contain `StatusRow`, `MenuRow`, `openAbout`, or `openWindowManagementSettings`.
- `ZapApp` uses `.menuBarExtraStyle(.menu)`.
- `SettingsView` includes `.about`, `aboutSection`, and `AboutView`.
- Tests match the implemented behavior.

- [ ] **Step 6: Final checkpoint**

Do not commit unless the user explicitly authorizes commits. If commits are authorized, use one final squashed-style commit instead of the optional task commits:

```bash
git add Sources/ZapApp/Views/MenuBarView.swift Sources/ZapApp/ZapApp.swift Sources/ZapApp/Views/SettingsView.swift Tests/ZapAppTests/MenuBarViewTests.swift Tests/ZapAppTests/SettingsWindowManagementUITests.swift docs/superpowers/specs/2026-06-10-zap-native-menu-bar-design.md docs/superpowers/plans/2026-06-10-zap-native-menu-bar.md
git commit -m "feat: use native menu bar submenus"
```

---

## Self-Review

### Spec coverage

- 권한 상태 삭제: Task 1 tests removed status expectations; Task 2 removes `StatusRow` and accessibility/status rendering from `MenuBarView`.
- Quick Launch 서브메뉴: Task 1 tests `Menu("Quick Launch")`; Task 2 implements Finder, manual shortcuts, and Dock apps inside that menu.
- Window Control 서브메뉴: Task 1 tests `Menu("Window Control")`; Task 2 implements window shortcut action buttons from `windowManagementModel.windowShortcuts`.
- About 이동: Task 3 tests `.about`; Task 4 implements Settings `.about` mode and removes menu bar About wiring through Task 2.
- 기존 동작 유지: Task 2 delegates to existing model methods; Task 5 runs full tests and dev launch verification.

### Placeholder scan

Checked for forbidden placeholder markers and vague implementation instructions; none remain. Every new helper used in implementation code is defined in the same task.

### Type consistency

- `MenuBarView` initializer fields match the Task 2 `ZapApp.swift` construction.
- `WindowShortcutDisplay.shortcutTitle(for:)` already exists in `Sources/ZapApp/Models/WindowShortcutDisplay.swift`.
- `WindowActionCategory.allCases`, `WindowShortcut`, and `NumberKey.allCases` are available through `import ZapCore`.
- `AboutInfo.current`, `AboutPresentation.currentAppName`, and `AboutView` already exist and are reused by `SettingsView`.
