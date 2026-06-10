# Zap Settings General and Window Rows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fold system settings into a single General page and simplify Window Management shortcut rows while preserving existing Zap model behavior.

**Architecture:** Keep the existing SwiftUI view hierarchy and model APIs. `SettingsView` owns top-level navigation and General content, `WindowManagementSettingsView` owns grouped shortcut sections, and `WindowShortcutRowView` owns per-action recording/enabled interactions. Tests follow the current project pattern of source-structure checks plus full `swift test` compilation.

**Tech Stack:** Swift 5.10, SwiftUI, AppKit, XCTest, Swift Package Manager, Makefile app bundling.

---

## File structure

- Modify `Sources/ZapApp/Views/SettingsView.swift`
  - Add `SettingsMode.general`.
  - Group sidebar items into `Shortcuts` and `System` sections.
  - Move Behavior and Updates into a new `generalSection`.
  - Add a `permissionsSection` that displays Accessibility status and request button.
  - Always show Finder in the Automatic Dock Apps grid, with disabled visual state when Finder shortcut is off.
- Modify `Sources/ZapApp/Views/WindowManagementSettingsView.swift`
  - Remove the top-level Accessibility Permission card.
  - Remove the Status card.
  - Keep errors inline inside the Shortcuts card.
  - Render Positioning as a two-column grid while leaving other categories single-column.
- Modify `Sources/ZapApp/Views/WindowShortcutRowView.swift`
  - Remove explicit `Record` and `Disable` buttons.
  - Make the keycap group a clickable recording target.
  - Use a right-side switch-style toggle for enabled/disabled state.
- Modify `Sources/ZapApp/Views/ZapDesignSystem.swift` only if a small shared style is needed; prefer reusing `SettingsCard`, `SettingsRow`, and existing keycap views.
- Modify tests:
  - `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`
  - `Tests/ZapAppTests/ZapDesignSystemTests.swift` only if a shared design-system behavior changes.

Commit steps in this plan are checkpoints only. In this session, do not run `git commit` unless the user explicitly asks for a commit.

---

### Task 1: Add General mode and grouped sidebar

**Files:**
- Modify: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`
- Modify: `Sources/ZapApp/Views/SettingsView.swift`

- [ ] **Step 1: Write the failing tests**

Add or replace these tests in `SettingsWindowManagementUITests`:

```swift
func testSettingsModeIncludesShortcutModesAndGeneral() {
    XCTAssertEqual(SettingsMode.allCases.map(\.title), [
        "Automatic",
        "Manual",
        "Window Management",
        "General"
    ])
}

func testSettingsSidebarGroupsShortcutModesAndSystemGeneral() throws {
    let source = try String(contentsOf: packageRootURL
        .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

    XCTAssertTrue(source.contains("sidebarSection(title: \"Shortcuts\", modes: [.automatic, .manual, .windowManagement])"))
    XCTAssertTrue(source.contains("sidebarSection(title: \"System\", modes: [.general])"))
    XCTAssertTrue(source.contains("case .general:"))
    XCTAssertTrue(source.contains("generalSection"))
}
```

If the existing `testSettingsModeIncludesAutomaticManualAndWindowManagement` exists, replace it with `testSettingsModeIncludesShortcutModesAndGeneral` so the test suite expects the new fourth mode.

- [ ] **Step 2: Run the tests to verify RED**

Run:

```bash
swift test --filter SettingsWindowManagementUITests
```

Expected: FAIL because `SettingsMode` does not have `general`, the sidebar does not call `sidebarSection(...)`, and `generalSection` is not routed.

- [ ] **Step 3: Implement the minimal SettingsMode and sidebar changes**

In `SettingsView.body`, replace the mode switch and common footer sections with:

```swift
switch selectedMode {
case .automatic:
    automaticShortcutsSection
    automaticSection
case .manual:
    manualSection
case .windowManagement:
    WindowManagementSettingsView(model: model.windowManagementModel, registrationError: model.registrationError)
case .general:
    generalSection
}
```

Remove these two lines from below the switch:

```swift
behaviorSection
updatesSection
```

Replace `settingsSidebar` with grouped sections:

```swift
private var settingsSidebar: some View {
    VStack(alignment: .leading, spacing: 8) {
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
        .padding(.bottom, 12)

        sidebarSection(title: "Shortcuts", modes: [.automatic, .manual, .windowManagement])

        sidebarSection(title: "System", modes: [.general])
            .padding(.top, 10)

        Spacer()
    }
    .padding(14)
    .frame(width: 178)
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .background(.bar)
}

private func sidebarSection(title: String, modes: [SettingsMode]) -> some View {
    VStack(alignment: .leading, spacing: 5) {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 10)

        ForEach(modes) { mode in
            SettingsSidebarItem(
                mode: mode,
                isSelected: selectedMode == mode
            ) {
                selectedMode = mode
            }
        }
    }
}
```

Update `SettingsMode`:

```swift
enum SettingsMode: String, CaseIterable, Identifiable {
    case automatic
    case manual
    case windowManagement
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .manual: "Manual"
        case .windowManagement: "Window Management"
        case .general: "General"
        }
    }

    var subtitle: String {
        switch self {
        case .automatic: "Launch Dock apps and Finder with predictable number shortcuts."
        case .manual: "Assign specific global shortcuts to apps outside the Dock."
        case .windowManagement: "Move and resize the frontmost window with Spectacle-style shortcuts."
        case .general: "Manage app behavior, permissions, and updates."
        }
    }

    var systemImage: String {
        switch self {
        case .automatic: "sparkle"
        case .manual: "keyboard"
        case .windowManagement: "rectangle.3.group"
        case .general: "gearshape"
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify GREEN**

Run:

```bash
swift test --filter SettingsWindowManagementUITests
```

Expected: PASS for the new sidebar/mode tests. If other tests fail because they still expect three modes, update those tests to the four-mode expectation above.

- [ ] **Step 5: Checkpoint**

Run:

```bash
git diff -- Sources/ZapApp/Views/SettingsView.swift Tests/ZapAppTests/SettingsWindowManagementUITests.swift
```

Expected: diff shows only the mode/sidebar routing changes for this task. Do not commit unless explicitly authorized.

---

### Task 2: Move Permissions, Behavior, and Updates into General

**Files:**
- Modify: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`
- Modify: `Sources/ZapApp/Views/SettingsView.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `SettingsWindowManagementUITests`:

```swift
func testGeneralSectionOwnsPermissionsBehaviorAndUpdates() throws {
    let source = try String(contentsOf: packageRootURL
        .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

    XCTAssertTrue(source.contains("private var generalSection: some View"))
    XCTAssertTrue(source.contains("permissionsSection"))
    XCTAssertTrue(source.contains("SettingsCard(title: \"Permissions\")"))
    XCTAssertTrue(source.contains("Accessibility"))
    XCTAssertTrue(source.contains("Granted"))
    XCTAssertTrue(source.contains("Button(\"Request\")"))
    XCTAssertFalse(source.contains("Required"))
    XCTAssertTrue(source.contains("SettingsCard(title: \"Behavior\")"))
    XCTAssertTrue(source.contains("SettingsCard(title: \"Updates\")"))
}

func testSettingsBodyDoesNotAppendBehaviorAndUpdatesToEveryMode() throws {
    let source = try String(contentsOf: packageRootURL
        .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

    XCTAssertFalse(source.contains("case .windowManagement:\n                        WindowManagementSettingsView(model: model.windowManagementModel, registrationError: model.registrationError)\n                    }\n\n                    behaviorSection\n                    updatesSection"))
}
```

- [ ] **Step 2: Run the tests to verify RED**

Run:

```bash
swift test --filter SettingsWindowManagementUITests
```

Expected: FAIL because `generalSection` and `permissionsSection` do not exist yet and the string `Required` has not been deliberately excluded.

- [ ] **Step 3: Implement General sections**

Add this below `menuBarIconBinding` in `SettingsView.swift`:

```swift
private var generalSection: some View {
    VStack(alignment: .leading, spacing: ZapSpacing.large) {
        permissionsSection
        behaviorSection
        updatesSection
    }
}

private var permissionsSection: some View {
    SettingsCard(title: "Permissions") {
        SettingsRow {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
        } trailing: {
            if model.windowManagementModel.accessibilityTrusted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.system(.callout, design: .default, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                Button("Request") {
                    model.windowManagementModel.requestAccessibilityPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .environment(\.settingsRowTitle, "Accessibility")
    }
}
```

If `SettingsRow` does not support the `.environment(\.settingsRowTitle...)` call, do not add custom environment keys. Instead use this explicit row body, which compiles with the existing `SettingsRow` shape:

```swift
private var permissionsSection: some View {
    SettingsCard(title: "Permissions") {
        SettingsRow(
            title: "Accessibility",
            subtitle: "Allow Zap to move and resize windows.",
            leading: {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
            },
            trailing: {
                if model.windowManagementModel.accessibilityTrusted {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .font(.system(.callout, design: .default, weight: .semibold))
                        .foregroundStyle(.green)
                } else {
                    Button("Request") {
                        model.windowManagementModel.requestAccessibilityPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        )
    }
}
```

Use the second explicit implementation unless you already introduced an environment key. Keep the existing `behaviorSection` and `updatesSection` implementations, but they should now only be rendered from `generalSection`.

- [ ] **Step 4: Remove old common rendering**

Ensure the main `body` no longer renders `behaviorSection` and `updatesSection` after every selected mode. The only direct usage should be inside `generalSection`.

- [ ] **Step 5: Run the tests to verify GREEN**

Run:

```bash
swift test --filter SettingsWindowManagementUITests
```

Expected: PASS. If compilation fails from the first `SettingsRow` snippet, replace it with the explicit `SettingsRow(title:subtitle:leading:trailing:)` snippet above.

- [ ] **Step 6: Checkpoint**

Run:

```bash
git diff -- Sources/ZapApp/Views/SettingsView.swift Tests/ZapAppTests/SettingsWindowManagementUITests.swift
```

Expected: diff shows `generalSection`, `permissionsSection`, and removal of common footer sections. Do not commit unless explicitly authorized.

---

### Task 3: Always show Finder in Automatic Dock Apps

**Files:**
- Modify: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`
- Modify: `Sources/ZapApp/Views/SettingsView.swift`

- [ ] **Step 1: Write the failing test**

Add this test:

```swift
func testAutomaticDockAppsAlwaysIncludesFinderWithDisabledVisualState() throws {
    let source = try String(contentsOf: packageRootURL
        .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

    XCTAssertFalse(source.contains("if model.isFinderShortcutEnabled {\n                    ShortcutListRow(shortcut: model.finderShortcutTitle, title: \"Finder\")\n                }"))
    XCTAssertTrue(source.contains("ShortcutListRow(\n                        shortcut: model.finderShortcutTitle,\n                        title: \"Finder\",\n                        isDisabled: !model.isFinderShortcutEnabled\n                    )"))
    XCTAssertTrue(source.contains("var isDisabled = false"))
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
swift test --filter SettingsWindowManagementUITests/testAutomaticDockAppsAlwaysIncludesFinderWithDisabledVisualState
```

Expected: FAIL because Finder is currently wrapped in `if model.isFinderShortcutEnabled` and `ShortcutListRow` does not have a separate `isDisabled` flag.

- [ ] **Step 3: Implement Finder always-visible row**

In `automaticSection`, replace:

```swift
if model.isFinderShortcutEnabled {
    ShortcutListRow(shortcut: model.finderShortcutTitle, title: "Finder")
}
```

with:

```swift
ShortcutListRow(
    shortcut: model.finderShortcutTitle,
    title: "Finder",
    isDisabled: !model.isFinderShortcutEnabled
)
```

Update `ShortcutListRow` in `SettingsView.swift`:

```swift
private struct ShortcutListRow: View {
    let shortcut: String
    let title: String
    var isEmpty = false
    var isDisabled = false

    var body: some View {
        HStack(spacing: 8) {
            ShortcutKeycapGroupView(shortcut: shortcut, isDisabled: isEmpty || isDisabled)
                .frame(width: 80, alignment: .leading)
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isEmpty || isDisabled ? .secondary : .primary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(isEmpty ? 0.025 : 0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .opacity(isDisabled ? 0.62 : 1)
    }
}
```

Keep existing Dock slot rows using `isEmpty`:

```swift
ShortcutListRow(
    shortcut: model.shortcutTitle(for: key),
    title: model.dockItem(for: key)?.name ?? "Empty",
    isEmpty: model.dockItem(for: key) == nil
)
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```bash
swift test --filter SettingsWindowManagementUITests/testAutomaticDockAppsAlwaysIncludesFinderWithDisabledVisualState
```

Expected: PASS.

- [ ] **Step 5: Run all settings UI source tests**

Run:

```bash
swift test --filter SettingsWindowManagementUITests
```

Expected: PASS.

---

### Task 4: Remove Window Management permission card and Status card

**Files:**
- Modify: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`
- Modify: `Sources/ZapApp/Views/WindowManagementSettingsView.swift`

- [ ] **Step 1: Write the failing tests**

Replace the old permission/status expectations with these tests:

```swift
func testWindowManagementSettingsNoLongerOwnsAccessibilityPermissionCard() throws {
    let source = try String(contentsOf: packageRootURL
        .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

    XCTAssertFalse(source.contains("Accessibility Permission"))
    XCTAssertFalse(source.contains("Open Accessibility Settings"))
    XCTAssertFalse(source.contains("Request Permission"))
    XCTAssertFalse(source.contains("Refresh Permission"))
}

func testWindowManagementSettingsDeletesStatusCardButKeepsInlineErrors() throws {
    let source = try String(contentsOf: packageRootURL
        .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

    XCTAssertFalse(source.contains("SettingsCard(title: \"Status\")"))
    XCTAssertTrue(source.contains("shortcutErrorMessages"))
    XCTAssertTrue(source.contains("if let registrationError"))
    XCTAssertTrue(source.contains("if let shortcutRegistrationError = model.shortcutRegistrationError"))
    XCTAssertTrue(source.contains("if let windowManagementError = model.windowManagementError"))
}
```

Update any existing test named `testWindowManagementSettingsViewContainsPermissionEnableResetAndShortcutRows` so it no longer expects the three permission buttons. It should still expect:

```swift
XCTAssertTrue(source.contains("Enable window management shortcuts"))
XCTAssertTrue(source.contains("Reset to Defaults"))
XCTAssertTrue(source.contains("WindowShortcutRowView"))
XCTAssertTrue(source.contains("WindowShortcutCategoryGroup"))
```

- [ ] **Step 2: Run the tests to verify RED**

Run:

```bash
swift test --filter SettingsWindowManagementUITests
```

Expected: FAIL because `WindowManagementSettingsView` still contains the permission card and `errorMessages`/Status card.

- [ ] **Step 3: Implement WindowManagementSettingsView cleanup**

Replace the body with:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: ZapSpacing.large) {
        shortcutsSection
    }
}
```

Delete the entire `accessibilityPermissionSection` property.

Inside `shortcutsSection`, keep the global toggle enabled regardless of permission state:

```swift
Toggle("Enable window management shortcuts", isOn: Binding(
    get: { model.isWindowManagementEnabled },
    set: { model.setWindowManagementEnabled($0) }
))
```

Do not attach `.disabled(!model.accessibilityTrusted)` to this global toggle.

Keep the lock explanation inside the Shortcuts card:

```swift
if !model.accessibilityTrusted {
    Label("Grant Accessibility in General to edit and run window shortcuts.", systemImage: "lock.fill")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
}
```

Add inline errors at the bottom of `shortcutsSection`:

```swift
shortcutErrorMessages
```

Replace `errorMessages` with:

```swift
@ViewBuilder
private var shortcutErrorMessages: some View {
    if registrationError != nil || model.shortcutRegistrationError != nil || model.windowManagementError != nil {
        VStack(alignment: .leading, spacing: 6) {
            if let registrationError {
                Label(registrationError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let shortcutRegistrationError = model.shortcutRegistrationError {
                Label(shortcutRegistrationError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let windowManagementError = model.windowManagementError {
                Label(windowManagementError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
```

- [ ] **Step 4: Run the tests to verify GREEN**

Run:

```bash
swift test --filter SettingsWindowManagementUITests
```

Expected: PASS for permission/status removal tests.

---

### Task 5: Make Window shortcut rows keycap-click recording plus toggle

**Files:**
- Modify: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`
- Modify: `Sources/ZapApp/Views/WindowShortcutRowView.swift`

- [ ] **Step 1: Write the failing test**

Add this test:

```swift
func testWindowShortcutRowsUseKeycapClickForRecordingAndSwitchToggleForEnablement() throws {
    let rowSource = try String(contentsOf: packageRootURL
        .appendingPathComponent("Sources/ZapApp/Views/WindowShortcutRowView.swift"))

    XCTAssertFalse(rowSource.contains("Button(\"Record\")"))
    XCTAssertFalse(rowSource.contains("Button(\"Disable\")"))
    XCTAssertTrue(rowSource.contains("Button {\n                isRecording = true\n            } label: {\n                ShortcutKeycapGroupView"))
    XCTAssertTrue(rowSource.contains(".toggleStyle(.switch)"))
    XCTAssertTrue(rowSource.contains(".accessibilityLabel(\"Record shortcut for \\(shortcut.action.title)\")"))
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
swift test --filter SettingsWindowManagementUITests/testWindowShortcutRowsUseKeycapClickForRecordingAndSwitchToggleForEnablement
```

Expected: FAIL because the row still has explicit Record/Disable buttons and no clickable keycap button.

- [ ] **Step 3: Implement row interaction change**

In `WindowShortcutRowView.body`, replace the current keycap/toggle/buttons trailing controls with:

```swift
Button {
    isRecording = true
} label: {
    ShortcutKeycapGroupView(shortcut: shortcut.shortcutTitle, isDisabled: isLocked || !shortcut.isEnabled)
}
.buttonStyle(.plain)
.disabled(isLocked)
.accessibilityLabel("Record shortcut for \(shortcut.action.title)")
.help("Record shortcut")

Toggle("", isOn: Binding(
    get: { shortcut.isEnabled },
    set: setEnabled
))
.labelsHidden()
.toggleStyle(.switch)
.disabled(isLocked || shortcut.shortcutTitle == nil)
```

Delete the explicit `Button("Record")` and `Button("Disable")` blocks.

Keep the existing sheet:

```swift
.sheet(isPresented: $isRecording) {
    ShortcutRecorderView(
        windowActionName: shortcut.action.title,
        onRecord: { recordedShortcut in
            record(recordedShortcut)
            isRecording = false
        },
        onCancel: {
            isRecording = false
        }
    )
}
```

- [ ] **Step 4: Run the row test to verify GREEN**

Run:

```bash
swift test --filter SettingsWindowManagementUITests/testWindowShortcutRowsUseKeycapClickForRecordingAndSwitchToggleForEnablement
```

Expected: PASS.

- [ ] **Step 5: Compile all app tests**

Run:

```bash
swift test --filter ZapAppTests
```

Expected: PASS. If macOS renders `.toggleStyle(.switch)` differently in tests, compilation is the main check because source tests are structural.

---

### Task 6: Render Positioning shortcuts in two columns

**Files:**
- Modify: `Tests/ZapAppTests/SettingsWindowManagementUITests.swift`
- Modify: `Sources/ZapApp/Views/WindowManagementSettingsView.swift`

- [ ] **Step 1: Write the failing test**

Add this test:

```swift
func testWindowManagementPositioningCategoryUsesTwoColumnGrid() throws {
    let source = try String(contentsOf: packageRootURL
        .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

    XCTAssertTrue(source.contains("if category == .positioning"))
    XCTAssertTrue(source.contains("LazyVGrid(columns: positioningColumns"))
    XCTAssertTrue(source.contains("private let positioningColumns"))
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```bash
swift test --filter SettingsWindowManagementUITests/testWindowManagementPositioningCategoryUsesTwoColumnGrid
```

Expected: FAIL because `WindowShortcutCategoryGroup` uses only a single VStack.

- [ ] **Step 3: Implement two-column Positioning layout**

In `WindowShortcutCategoryGroup`, add a columns property:

```swift
private let positioningColumns = [
    GridItem(.flexible(), spacing: 8, alignment: .top),
    GridItem(.flexible(), spacing: 8, alignment: .top)
]
```

Replace the current inner `VStack(spacing: 0)` block with:

```swift
if category == .positioning {
    LazyVGrid(columns: positioningColumns, alignment: .leading, spacing: 0) {
        ForEach(shortcuts) { shortcut in
            WindowShortcutRowView(
                shortcut: shortcut,
                isLocked: isLocked,
                setEnabled: { isEnabled in setEnabled(shortcut, isEnabled) },
                record: { recordedShortcut in record(shortcut, recordedShortcut) }
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
} else {
    VStack(spacing: 0) {
        ForEach(shortcuts) { shortcut in
            WindowShortcutRowView(
                shortcut: shortcut,
                isLocked: isLocked,
                setEnabled: { isEnabled in setEnabled(shortcut, isEnabled) },
                record: { recordedShortcut in record(shortcut, recordedShortcut) }
            )

            if shortcut.id != shortcuts.last?.id {
                Divider()
                    .padding(.leading, 44)
            }
        }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
}
```

Keep the category header and `.opacity(isLocked ? 0.72 : 1)` wrapper unchanged.

- [ ] **Step 4: Run the Positioning test to verify GREEN**

Run:

```bash
swift test --filter SettingsWindowManagementUITests/testWindowManagementPositioningCategoryUsesTwoColumnGrid
```

Expected: PASS.

- [ ] **Step 5: Run all window management UI tests**

Run:

```bash
swift test --filter SettingsWindowManagementUITests
```

Expected: PASS.

---

### Task 7: Final verification and development app launch

**Files:**
- Verify all modified files.

- [ ] **Step 1: Run whitespace check**

Run:

```bash
git diff --check
```

Expected: no output and exit 0.

- [ ] **Step 2: Run full test suite**

Run:

```bash
swift test
```

Expected: all tests pass, currently expected around 142+ tests depending on added tests.

- [ ] **Step 3: Build and verify development app**

Run:

```bash
make dev-verify
```

Expected: output ends with:

```text
verification passed
```

- [ ] **Step 4: Launch development app**

Run:

```bash
open "/tmp/zap-bundles/dev/Zap dev.app"
```

Expected: command exits 0.

- [ ] **Step 5: Confirm process is running**

Run:

```bash
osascript -e 'tell application "System Events" to get name of every process whose bundle identifier is "com.woosublee.zap.dev"'
```

Expected:

```text
Zap dev
```

- [ ] **Step 6: Open Settings window through the app command**

Run:

```bash
osascript <<'APPLESCRIPT'
tell application "Zap dev" to activate
delay 0.5
tell application "System Events"
  keystroke "," using command down
  delay 0.5
  tell process "Zap dev"
    get name of every window
  end tell
end tell
APPLESCRIPT
```

Expected output contains:

```text
Zap dev Settings
```

- [ ] **Step 7: Report exact verification evidence**

Report:

- `git diff --check`: exit 0
- `swift test`: number of tests and 0 failures from output
- `make dev-verify`: `verification passed`
- `open`: exit 0
- process check: `Zap dev`
- settings window check: `Zap dev Settings`

Do not claim completion before these commands have been run and outputs read.

---

## Self-review against spec

- Sidebar structure: Task 1 covers `Shortcuts` group plus `System > General`.
- General content: Task 2 covers Permissions, Behavior, and Updates in one page.
- Finder always visible: Task 3 covers Finder row always shown and dimmed when disabled.
- Window Management cleanup: Task 4 covers permission section removal, Status removal, global toggle availability, and inline errors.
- Window row behavior: Task 5 covers keycap-click recording, switch toggle, Record/Disable button removal.
- Positioning 2-column layout: Task 6 covers Positioning-only `LazyVGrid`.
- Verification: Task 7 covers tests, build, app launch, and settings window interaction.

No placeholders remain. No model API changes are planned. No unrelated menu bar/About changes are included.
