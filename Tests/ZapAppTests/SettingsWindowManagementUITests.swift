import XCTest
@testable import ZapApp

final class SettingsWindowManagementUITests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testSettingsModeIncludesShortcutModesAndGeneral() {
        XCTAssertEqual(SettingsMode.allCases.map(\.title), [
            "Automatic",
            "Manual",
            "Window Management",
            "General",
            "About"
        ])
    }

    func testSettingsSidebarGroupsShortcutModesAndSystemGeneral() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("sidebarSection(title: \"Shortcuts\", modes: [.automatic, .manual, .windowManagement])"))
        XCTAssertTrue(source.contains("sidebarSection(title: \"System\", modes: [.general, .about])"))
        XCTAssertTrue(source.contains("case .general:"))
        XCTAssertTrue(source.contains("case .about:"))
        XCTAssertTrue(source.contains("generalSection"))
        XCTAssertTrue(source.contains("aboutSection"))
        XCTAssertFalse(source.contains("case .setting"))
        XCTAssertFalse(source.contains("settingSection"))
        XCTAssertFalse(source.contains("\"Setting\""))
    }

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

    func testSettingsViewRoutesWindowManagementModeAndKeepsExistingModes() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("case automatic"))
        XCTAssertTrue(source.contains("case manual"))
        XCTAssertTrue(source.contains("case windowManagement"))
        XCTAssertTrue(source.contains("Window Management"))
        XCTAssertTrue(source.contains("WindowManagementSettingsView"))
    }

    func testSettingsViewUsesSidebarLayoutForModeNavigation() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("settingsSidebar"))
        XCTAssertTrue(source.contains("SettingsSidebarItem"))
        XCTAssertTrue(source.contains("frame(width: 820, height: 640)"))
        XCTAssertFalse(source.contains(".pickerStyle(.segmented)"))
    }

    func testSettingsWindowPresenterMatchesRedesignedSettingsViewWidth() throws {
        let presenterSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Services/SettingsWindowPresenter.swift"))
        let settingsSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(settingsSource.contains("frame(width: 820, height: 640)"))
        XCTAssertTrue(presenterSource.contains("width: 820"))
    }

    func testSettingsWindowPreservesStateAndCanRouteToRequestedMode() throws {
        let presenterSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Services/SettingsWindowPresenter.swift"))
        let settingsSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))
        let appSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/ZapApp.swift"))

        XCTAssertTrue(settingsSource.contains("final class SettingsNavigationState: ObservableObject"))
        XCTAssertTrue(settingsSource.contains("@Published var selectedMode: SettingsMode"))
        XCTAssertTrue(settingsSource.contains("nonmutating set { navigationState.selectedMode = newValue }"))
        XCTAssertTrue(presenterSource.contains("private static var navigationState = SettingsNavigationState()"))
        XCTAssertTrue(presenterSource.contains("initialMode: SettingsMode? = nil"))
        XCTAssertTrue(presenterSource.contains("navigationState = SettingsNavigationState(selectedMode: initialMode ?? .automatic)"))
        XCTAssertTrue(presenterSource.contains("navigationState.selectedMode = initialMode"))
        XCTAssertTrue(appSource.contains("private func openSettings(initialMode: SettingsMode? = nil)"))
        XCTAssertFalse(presenterSource.contains("window.contentViewController = NSHostingController(\n            rootView: SettingsView(model: model"))
    }

    func testSettingsSidebarAnnouncesSelectedModeForAccessibility() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("accessibilityValue(isSelected ? \"Selected\" : \"Not selected\")"))
    }

    func testSettingsSidebarItemUsesFullRowHitArea() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains(".padding(.vertical, 8)\n            .frame(maxWidth: .infinity, alignment: .leading)\n            .contentShape(Rectangle())\n            .background("))
    }

    func testGeneralSectionOwnsPermissionsBehaviorAndUpdates() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("private var generalSection: some View"))
        XCTAssertTrue(source.contains("permissionsSection"))
        XCTAssertTrue(source.contains("SettingsCard(title: \"Permissions\")"))
        XCTAssertTrue(source.contains("Accessibility"))
        XCTAssertTrue(source.contains("Granted"))
        XCTAssertTrue(source.contains("Button(\"Request\")"))
        XCTAssertTrue(source.contains("model.windowManagementModel.requestAccessibilityPermission()\n                            refreshAccessibilityPermission()"))
        XCTAssertTrue(source.contains(".onAppear {\n            refreshAccessibilityPermission()\n        }"))
        XCTAssertTrue(source.contains("NSApplication.didBecomeActiveNotification"))
        XCTAssertTrue(source.contains("model.windowManagementModel.refreshAccessibilityPermission()"))
        XCTAssertFalse(source.contains("Required"))
        XCTAssertTrue(source.contains("SettingsCard(title: \"Behavior\")"))
        XCTAssertTrue(source.contains("SettingsCard(title: \"Updates\")"))
    }

    func testSettingsBodyDoesNotAppendBehaviorAndUpdatesToEveryMode() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertFalse(source.contains("case .windowManagement:\n                        WindowManagementSettingsView(model: model.windowManagementModel, registrationError: model.registrationError)\n                    }\n\n                    behaviorSection\n                    updatesSection"))
    }

    func testAutomaticDockAppsAlwaysIncludesFinderWithDisabledVisualState() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertFalse(source.contains("if model.isFinderShortcutEnabled {\n                    ShortcutListRow(shortcut: model.finderShortcutTitle, title: \"Finder\")\n                }"))
        XCTAssertTrue(source.contains("ShortcutListRow(\n                    shortcut: model.finderShortcutTitle,\n                    title: \"Finder\",\n                    isDisabled: !model.isFinderShortcutEnabled\n                )"))
        XCTAssertTrue(source.contains("var isDisabled = false"))
    }

    func testFinderShortcutUsesSwitchToggleStyle() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("Toggle(\"Finder shortcut\", isOn: $model.isFinderShortcutEnabled)"))
        XCTAssertTrue(source.contains(".toggleStyle(.switch)"))
        XCTAssertFalse(source.contains("Toggle(isOn: $model.isFinderShortcutEnabled) {\n                HStack(spacing: 8)"))
    }

    func testManualShortcutRowsUseOneLineKeycapClickAndSwitchToggle() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("Button {\n                record()\n            } label: {\n                ShortcutKeycapGroupView"))
        XCTAssertTrue(source.contains(".accessibilityLabel(\"Record shortcut for \\(shortcut.name)\")"))
        XCTAssertTrue(source.contains(".toggleStyle(.switch)"))
        XCTAssertFalse(source.contains("Button(\"Record\")"))
        XCTAssertFalse(source.contains("private struct ManualShortcutRow: View {\n    let shortcut: ManualShortcut\n    let setEnabled: (Bool) -> Void\n    let record: () -> Void\n    let remove: () -> Void\n\n    var body: some View {\n        HStack(alignment: .center, spacing: 10) {\n            VStack"))
    }

    func testSettingsWindowWidthSupportsFullSidebarAndTwoColumnWindowShortcuts() throws {
        let presenterSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Services/SettingsWindowPresenter.swift"))
        let settingsSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(settingsSource.contains("frame(width: 820, height: 640)"))
        XCTAssertTrue(settingsSource.contains("frame(width: 216)"))
        XCTAssertTrue(presenterSource.contains("width: 820"))
    }

    func testSettingsWindowUsesNormalLevelAndNaturalOrdering() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Services/SettingsWindowPresenter.swift"))

        XCTAssertFalse(source.contains("window.level = .floating"))
        XCTAssertFalse(source.contains("window.orderFrontRegardless()"))
    }

    func testWindowManagementUsesSharedAdaptiveTwoColumnRowsForEveryCategory() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

        XCTAssertTrue(source.contains("private let shortcutColumns = ["))
        XCTAssertTrue(source.contains("GridItem(.adaptive(minimum: 240)"))
        XCTAssertTrue(source.contains("LazyVGrid(columns: shortcutColumns"))
        XCTAssertFalse(source.contains("LazyVGrid(columns: positioningColumns"))
        XCTAssertFalse(source.contains("private let positioningColumns"))
        XCTAssertFalse(source.contains("if category == .positioning"))
    }

    func testWindowManagementGlobalToggleUsesSwitchStyle() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

        XCTAssertTrue(source.contains("Toggle(\"Enable window management shortcuts\", isOn: Binding("))
        XCTAssertTrue(source.contains(".toggleStyle(.switch)"))
    }

    func testWindowShortcutRowsPlaceDiagramTitleShortcutAndIconEnableButtonInSingleLine() throws {
        let rowSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowShortcutRowView.swift"))

        XCTAssertFalse(rowSource.contains("showsSupportingText"))
        XCTAssertFalse(rowSource.contains("VStack(alignment: .leading, spacing: 7)"))
        XCTAssertTrue(rowSource.contains("WindowActionDiagramView(action: shortcut.action)"))
        XCTAssertTrue(rowSource.contains("Text(shortcut.action.title)"))
        XCTAssertTrue(rowSource.contains("let inputSourceRevision: Int"))
        XCTAssertTrue(rowSource.contains("_ = inputSourceRevision"))
        XCTAssertTrue(rowSource.contains("ShortcutKeycapGroupView(shortcut: shortcutTitle"))
        XCTAssertTrue(rowSource.contains("Image(systemName: shortcut.isEnabled ? \"checkmark.circle.fill\" : \"circle\")"))
        XCTAssertTrue(rowSource.contains("setEnabled(!shortcut.isEnabled)"))
        XCTAssertFalse(rowSource.contains("Toggle(\"\", isOn: Binding("))
    }

    func testSettingsStillContainsBehaviorAndSparkleUpdateControls() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("SettingsCard(title: \"Behavior\")"))
        XCTAssertTrue(source.contains("Launch at login"))
        XCTAssertTrue(source.contains("Show menu bar icon"))
        XCTAssertTrue(source.contains("SettingsCard(title: \"Updates\")"))
        XCTAssertTrue(source.contains("Automatically check for updates"))
        XCTAssertTrue(source.contains("Check for Updates Now"))
        XCTAssertTrue(source.contains("Updates are delivered with Sparkle"))
    }

    func testAutomaticAndManualShortcutControlsRemainWired() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertTrue(source.contains("automaticShortcutsSection"))
        XCTAssertTrue(source.contains("Finder shortcut"))
        XCTAssertTrue(source.contains("Dock app shortcuts"))
        XCTAssertTrue(source.contains("manualSection"))
        XCTAssertTrue(source.contains("ManualShortcutRow"))
        XCTAssertTrue(source.contains("Add App Shortcut"))
    }

    func testWindowManagementSettingsViewContainsEnableResetAndShortcutRows() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

        XCTAssertTrue(source.contains("Enable window management shortcuts"))
        XCTAssertTrue(source.contains("Reset to Defaults"))
        XCTAssertTrue(source.contains("WindowShortcutRowView"))
        XCTAssertTrue(source.contains("WindowShortcutCategoryGroup"))
    }

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

    func testWindowManagementSettingsGroupsShortcutsByCategoryAndLocksWhenPermissionIsMissing() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))
        let rowSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowShortcutRowView.swift"))

        XCTAssertTrue(source.contains("WindowShortcutCategoryGroup"))
        XCTAssertTrue(source.contains("shortcutsByCategory"))
        XCTAssertFalse(source.contains("Text(\"\\(shortcuts.count)\")"))
        XCTAssertTrue(source.contains("WindowActionCategory.allCases"))
        XCTAssertTrue(source.contains("!model.accessibilityTrusted"))
        XCTAssertTrue(rowSource.contains("WindowActionDiagramView"))
        XCTAssertTrue(rowSource.contains("ShortcutKeycapGroupView"))
    }

    func testWindowManagementGlobalToggleRemainsAvailableWithoutAccessibilityPermission() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

        XCTAssertFalse(source.contains(".disabled(!model.accessibilityTrusted)"))
        XCTAssertTrue(source.contains("WindowShortcutCategoryGroup"))
        XCTAssertTrue(source.contains("shortcutColumns"))
        XCTAssertTrue(source.contains("isLocked: !model.accessibilityTrusted"))
        XCTAssertTrue(source.contains("Grant Accessibility in General to enable and run window shortcuts."))
    }

    func testWindowManagementSettingsReceivesAndDisplaysGlobalRegistrationError() throws {
        let settingsSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))
        let windowManagementSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

        XCTAssertTrue(settingsSource.contains("WindowManagementSettingsView("))
        XCTAssertTrue(settingsSource.contains("model: model.windowManagementModel"))
        XCTAssertTrue(settingsSource.contains("registrationError: model.registrationError"))
        XCTAssertTrue(settingsSource.contains("inputSourceRevision: model.inputSourceRevision"))
        XCTAssertTrue(windowManagementSource.contains("let registrationError: String?"))
        XCTAssertTrue(windowManagementSource.contains("let inputSourceRevision: Int"))
        XCTAssertTrue(windowManagementSource.contains("if let registrationError"))
        XCTAssertTrue(windowManagementSource.contains("Label(registrationError"))
    }

    func testWindowShortcutRowsUseKeycapClickForRecordingAndIconButtonForEnablement() throws {
        let rowSource = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowShortcutRowView.swift"))

        XCTAssertFalse(rowSource.contains("Button(\"Record\")"))
        XCTAssertFalse(rowSource.contains("Button(\"Disable\")"))
        XCTAssertTrue(rowSource.contains("private var canRecordShortcut: Bool"))
        XCTAssertTrue(rowSource.contains("guard canRecordShortcut else { return }"))
        XCTAssertTrue(rowSource.contains("ShortcutKeycapGroupView(shortcut: shortcutTitle, isDisabled: !canRecordShortcut)"))
        XCTAssertTrue(rowSource.contains(".disabled(!canRecordShortcut)"))
        XCTAssertFalse(rowSource.contains("ShortcutKeycapGroupView(shortcut: shortcutTitle, isDisabled: !shortcut.isEnabled)"))
        XCTAssertTrue(rowSource.contains("Button {\n                setEnabled(!shortcut.isEnabled)\n            } label: {"))
        XCTAssertTrue(rowSource.contains(".accessibilityLabel(shortcut.isEnabled ? \"Disable \\(shortcut.action.title)\" : \"Enable \\(shortcut.action.title)\")"))
        XCTAssertFalse(rowSource.contains(".toggleStyle(.switch)"))
        XCTAssertTrue(rowSource.contains(".accessibilityLabel(\"Record shortcut for \\(shortcut.action.title)\")"))
    }

    func testWindowManagementPositioningCategoryUsesSharedTwoColumnGrid() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/WindowManagementSettingsView.swift"))

        XCTAssertFalse(source.contains("if category == .positioning"))
        XCTAssertTrue(source.contains("LazyVGrid(columns: shortcutColumns"))
        XCTAssertFalse(source.contains("private let positioningColumns"))
    }
}
