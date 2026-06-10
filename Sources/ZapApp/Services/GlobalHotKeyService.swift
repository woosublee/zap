import Carbon
import Foundation
import ZapCore

struct HotKeyCombo: Hashable {
    let keyCode: UInt32
    let modifiers: UInt32
}

struct PlannedHotKey: Equatable {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32
    let owner: PlannedHotKeyOwner
}

enum PlannedHotKeyOwner: Equatable {
    case finder
    case dock(NumberKey)
    case manual(UUID, name: String)
    case window(WindowAction, title: String)
}

struct HotKeyRegistrationPlan: Equatable {
    let hotKeys: [PlannedHotKey]
    let errors: [String]
}

struct HotKeyRegistrationResult {
    let status: OSStatus
    let ref: EventHotKeyRef?
}

protocol GlobalHotKeyServicing: AnyObject {
    func register(
        modifiers: Set<ShortcutModifier>,
        finderShortcutEnabled: Bool,
        manualShortcuts: [ManualShortcut],
        windowShortcuts: [WindowShortcut]
    ) -> String?

    func unregister()
}

struct GlobalHotKeyRegistrationPlanner {
    private static let finderHotKeys: [(keyCode: UInt32, id: UInt32)] = [
        (UInt32(kVK_ANSI_Grave), 100),
        (UInt32(kVK_JIS_Yen), 101),
        (UInt32(kVK_ANSI_Backslash), 102),
        (UInt32(kVK_ISO_Section), 103)
    ]

    func plan(
        modifiers: Set<ShortcutModifier>,
        finderShortcutEnabled: Bool,
        manualShortcuts: [ManualShortcut],
        windowShortcuts: [WindowShortcut]
    ) -> HotKeyRegistrationPlan {
        var plannedHotKeys: [PlannedHotKey] = []
        var errors: [String] = []
        var registeredCombos = Set<HotKeyCombo>()

        if finderShortcutEnabled {
            planFinderHotKeys(into: &plannedHotKeys, registeredCombos: &registeredCombos)
        }

        if modifiers.isEmpty {
            errors.append("Select at least one modifier key.")
        } else {
            let dockFailures = planDockHotKeys(
                modifiers: modifiers,
                into: &plannedHotKeys,
                registeredCombos: &registeredCombos
            )
            if !dockFailures.isEmpty {
                errors.append("Some Dock shortcuts could not be registered: \(dockFailures.joined(separator: ", "))")
            }
        }

        let manualFailures = planManualHotKeys(
            manualShortcuts,
            into: &plannedHotKeys,
            registeredCombos: &registeredCombos
        )
        if !manualFailures.isEmpty {
            errors.append("Some manual shortcuts could not be registered: \(manualFailures.joined(separator: ", "))")
        }

        let windowFailures = planWindowHotKeys(
            windowShortcuts,
            into: &plannedHotKeys,
            registeredCombos: &registeredCombos
        )
        if !windowFailures.isEmpty {
            errors.append("Some window shortcuts could not be registered: \(windowFailures.joined(separator: ", "))")
        }

        return HotKeyRegistrationPlan(hotKeys: plannedHotKeys, errors: errors)
    }

    private func planFinderHotKeys(
        into plannedHotKeys: inout [PlannedHotKey],
        registeredCombos: inout Set<HotKeyCombo>
    ) {
        let modifiers = UInt32(optionKey)
        for hotKey in Self.finderHotKeys {
            let combo = HotKeyCombo(keyCode: hotKey.keyCode, modifiers: modifiers)
            guard !registeredCombos.contains(combo) else { continue }
            plannedHotKeys.append(PlannedHotKey(
                id: hotKey.id,
                keyCode: hotKey.keyCode,
                modifiers: modifiers,
                owner: .finder
            ))
            registeredCombos.insert(combo)
        }
    }

    private func planDockHotKeys(
        modifiers: Set<ShortcutModifier>,
        into plannedHotKeys: inout [PlannedHotKey],
        registeredCombos: inout Set<HotKeyCombo>
    ) -> [String] {
        let carbonModifiers = Self.carbonModifiers(for: modifiers)
        var failures: [String] = []

        for key in NumberKey.allCases {
            let combo = HotKeyCombo(keyCode: key.carbonKeyCode, modifiers: carbonModifiers)
            if registeredCombos.contains(combo) {
                failures.append("\(key.displayName) (conflict)")
                continue
            }
            plannedHotKeys.append(PlannedHotKey(
                id: UInt32(key.rawValue),
                keyCode: key.carbonKeyCode,
                modifiers: carbonModifiers,
                owner: .dock(key)
            ))
            registeredCombos.insert(combo)
        }

        return failures
    }

    private func planManualHotKeys(
        _ shortcuts: [ManualShortcut],
        into plannedHotKeys: inout [PlannedHotKey],
        registeredCombos: inout Set<HotKeyCombo>
    ) -> [String] {
        var failures: [String] = []

        for (index, shortcut) in shortcuts.enumerated() {
            guard shortcut.isEnabled,
                  let keyCode = shortcut.keyCode,
                  !shortcut.modifiers.isEmpty else {
                continue
            }

            let carbonModifiers = Self.carbonModifiers(for: shortcut.modifiers)
            let combo = HotKeyCombo(keyCode: keyCode, modifiers: carbonModifiers)
            if registeredCombos.contains(combo) {
                failures.append("\(shortcut.name) (conflict)")
                continue
            }

            plannedHotKeys.append(PlannedHotKey(
                id: UInt32(1000 + index),
                keyCode: keyCode,
                modifiers: carbonModifiers,
                owner: .manual(shortcut.id, name: shortcut.name)
            ))
            registeredCombos.insert(combo)
        }

        return failures
    }

    private func planWindowHotKeys(
        _ shortcuts: [WindowShortcut],
        into plannedHotKeys: inout [PlannedHotKey],
        registeredCombos: inout Set<HotKeyCombo>
    ) -> [String] {
        var failures: [String] = []

        for (index, shortcut) in shortcuts.enumerated() {
            guard shortcut.canRegister,
                  let keyCode = shortcut.keyCode else {
                continue
            }

            let carbonModifiers = Self.carbonModifiers(for: shortcut.modifiers)
            let combo = HotKeyCombo(keyCode: keyCode, modifiers: carbonModifiers)
            if registeredCombos.contains(combo) {
                failures.append("\(shortcut.action.displayName) (conflict)")
                continue
            }

            plannedHotKeys.append(PlannedHotKey(
                id: UInt32(2000 + index),
                keyCode: keyCode,
                modifiers: carbonModifiers,
                owner: .window(shortcut.action, title: shortcut.action.displayName)
            ))
            registeredCombos.insert(combo)
        }

        return failures
    }

    static func carbonModifiers(for modifiers: Set<ShortcutModifier>) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

final class GlobalHotKeyService: GlobalHotKeyServicing {
    private static let finderHotKeyIDs: Set<UInt32> = [100, 101, 102, 103]
    private static let hotKeySignature = OSType(0x534E4150)

    private let hotKeySignature = GlobalHotKeyService.hotKeySignature
    private let onDockHotKey: (NumberKey) -> Void
    private let onFinderHotKey: () -> Void
    private let onManualHotKey: (UUID) -> Void
    private let onWindowHotKey: (WindowAction) -> Void
    private let planner: GlobalHotKeyRegistrationPlanner
    private let registerHotKey: (PlannedHotKey) -> HotKeyRegistrationResult
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var manualHotKeyIDs: [UInt32: UUID] = [:]
    private var windowHotKeyIDs: [UInt32: WindowAction] = [:]
    private var handlerRef: EventHandlerRef?

    init(
        onDockHotKey: @escaping (NumberKey) -> Void,
        onFinderHotKey: @escaping () -> Void,
        onManualHotKey: @escaping (UUID) -> Void,
        onWindowHotKey: @escaping (WindowAction) -> Void,
        planner: GlobalHotKeyRegistrationPlanner = GlobalHotKeyRegistrationPlanner(),
        registerHotKey: @escaping (PlannedHotKey) -> HotKeyRegistrationResult = GlobalHotKeyService.registerCarbonHotKey
    ) {
        self.onDockHotKey = onDockHotKey
        self.onFinderHotKey = onFinderHotKey
        self.onManualHotKey = onManualHotKey
        self.onWindowHotKey = onWindowHotKey
        self.planner = planner
        self.registerHotKey = registerHotKey
        installHandler()
    }

    deinit {
        unregister()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    func register(
        modifiers: Set<ShortcutModifier>,
        finderShortcutEnabled: Bool,
        manualShortcuts: [ManualShortcut],
        windowShortcuts: [WindowShortcut] = []
    ) -> String? {
        unregister()

        let plan = planner.plan(
            modifiers: modifiers,
            finderShortcutEnabled: finderShortcutEnabled,
            manualShortcuts: manualShortcuts,
            windowShortcuts: windowShortcuts
        )
        var errors = plan.errors
        var finderFailures: [String] = []
        var dockFailures: [String] = []
        var manualFailures: [String] = []
        var windowFailures: [String] = []

        for hotKey in plan.hotKeys {
            let result = registerHotKey(hotKey)
            if result.status == noErr {
                if let ref = result.ref {
                    hotKeyRefs.append(ref)
                }
                registerSuccessfulOwner(for: hotKey)
            } else {
                switch hotKey.owner {
                case .finder:
                    finderFailures.append("\(hotKey.keyCode) (\(result.status))")
                case let .dock(key):
                    dockFailures.append("\(key.displayName) (\(result.status))")
                case let .manual(_, name):
                    manualFailures.append("\(name) (\(result.status))")
                case let .window(_, title):
                    windowFailures.append("\(title) (\(result.status))")
                }
            }
        }

        if !finderFailures.isEmpty {
            errors.append("Finder shortcut could not be registered for all ₩/` variants: \(finderFailures.joined(separator: ", "))")
        }
        if !dockFailures.isEmpty {
            errors.append("Some Dock shortcuts could not be registered: \(dockFailures.joined(separator: ", "))")
        }
        if !manualFailures.isEmpty {
            errors.append("Some manual shortcuts could not be registered: \(manualFailures.joined(separator: ", "))")
        }
        if !windowFailures.isEmpty {
            errors.append("Some window shortcuts could not be registered: \(windowFailures.joined(separator: ", "))")
        }

        return errors.isEmpty ? nil : errors.joined(separator: " ")
    }

    func unregister() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        manualHotKeyIDs.removeAll()
        windowHotKeyIDs.removeAll()
    }

    @discardableResult
    func dispatchHotKey(id: UInt32) -> Bool {
        if Self.finderHotKeyIDs.contains(id) {
            DispatchQueue.main.async { [onFinderHotKey] in
                onFinderHotKey()
            }
            return true
        }

        if let manualShortcutID = manualHotKeyIDs[id] {
            DispatchQueue.main.async { [onManualHotKey] in
                onManualHotKey(manualShortcutID)
            }
            return true
        }

        if let windowAction = windowHotKeyIDs[id] {
            DispatchQueue.main.async { [onWindowHotKey] in
                onWindowHotKey(windowAction)
            }
            return true
        }

        guard let key = NumberKey(rawValue: Int(id)) else {
            return false
        }

        DispatchQueue.main.async { [onDockHotKey] in
            onDockHotKey(key)
        }
        return true
    }

    private func registerSuccessfulOwner(for hotKey: PlannedHotKey) {
        switch hotKey.owner {
        case .finder, .dock:
            break
        case let .manual(id, _):
            manualHotKeyIDs[hotKey.id] = id
        case let .window(action, _):
            windowHotKeyIDs[hotKey.id] = action
        }
    }

    private func installHandler() {
        guard handlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                let service = Unmanaged<GlobalHotKeyService>.fromOpaque(userData).takeUnretainedValue()
                return service.handle(event: event)
            },
            1,
            &eventType,
            userData,
            &handlerRef
        )
    }

    private func handle(event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr,
              hotKeyID.signature == hotKeySignature else {
            return status
        }

        dispatchHotKey(id: hotKeyID.id)
        return noErr
    }

    private static func registerCarbonHotKey(_ hotKey: PlannedHotKey) -> HotKeyRegistrationResult {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKey.id)
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        return HotKeyRegistrationResult(status: status, ref: ref)
    }
}
