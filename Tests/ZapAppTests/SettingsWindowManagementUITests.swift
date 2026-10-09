import XCTest
@testable import ZapApp

final class SettingsWindowManagementUITests: XCTestCase {
    private var packageRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

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

    func testSettingsNoLongerHasAboutScreen() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertFalse(source.contains("aboutSection"))
        XCTAssertFalse(source.contains("AboutView("))
        XCTAssertFalse(source.contains("case .about"))
    }

    func testSettingsContentDoesNotRenderPerModeHeader() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertFalse(source.contains("settingsHeader"))
        XCTAssertFalse(source.contains("Text(selectedMode.title)"))
        XCTAssertFalse(source.contains("selectedMode.subtitle"))
    }

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
        XCTAssertTrue(presenterSource.contains("SettingsMode.initial(\n                    requested: initialMode,"))
        XCTAssertTrue(presenterSource.contains("storedRawValue: UserDefaults.standard.string(forKey: SettingsMode.lastModeDefaultsKey)"))
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
        XCTAssertTrue(source.contains("title: AccessibilityPaneName.current"))
        XCTAssertTrue(source.contains("Required for window shortcuts and per-app toggling."))
        XCTAssertTrue(source.contains("Granted"))
        XCTAssertTrue(source.contains("Button(\"Grant…\")"))
        XCTAssertFalse(source.contains("Button(\"Request\")"))
        XCTAssertTrue(source.contains("model.windowManagementModel.requestAccessibilityPermission(\n                                sourceFrame: PermissionGuideSourceFrame.atMouse\n                            )\n                            refreshAccessibilityPermission()"))
        XCTAssertTrue(source.contains(".onAppear {\n            refreshAccessibilityPermission()\n        }"))
        XCTAssertTrue(source.contains("NSApplication.didBecomeActiveNotification"))
        XCTAssertTrue(source.contains("model.windowManagementModel.refreshAccessibilityPermission()"))
        XCTAssertFalse(source.contains("Text(\"Required\")"))
        XCTAssertFalse(source.contains("Label(\"Required\""))
        XCTAssertTrue(source.contains("SettingsCard(title: \"Behavior\")"))
        XCTAssertTrue(source.contains("SettingsCard(title: \"Updates\")"))
        XCTAssertTrue(source.contains("if AppDistribution.current.supportsInAppUpdates {\n                updatesSection\n            }"))
        XCTAssertTrue(source.contains("case .general:\n                        SettingsIssueBanner(messages: [model.registrationError])\n                        generalSection"))
    }

    func testSettingsBodyDoesNotAppendBehaviorAndUpdatesToEveryMode() throws {
        let source = try String(contentsOf: packageRootURL
            .appendingPathComponent("Sources/ZapApp/Views/SettingsView.swift"))

        XCTAssertFalse(source.contains("case .windowManagement:\n                        WindowManagementSettingsView(model: model.windowManagementModel, registrationError: model.registrationError)\n                    }\n\n                    behaviorSection\n                    updatesSection"))
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
}
