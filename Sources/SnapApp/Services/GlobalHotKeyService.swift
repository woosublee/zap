import Carbon
import Foundation
import SnapCore

final class GlobalHotKeyService {
    private static let finderHotKeys: [(keyCode: UInt32, id: UInt32)] = [
        (UInt32(kVK_ANSI_Grave), 100),
        (UInt32(kVK_JIS_Yen), 101),
        (UInt32(kVK_ANSI_Backslash), 102),
        (UInt32(kVK_ISO_Section), 103)
    ]
    private static let finderHotKeyIDs = Set(finderHotKeys.map(\.id))

    private let hotKeySignature = OSType(0x534E4150)
    private let onDockHotKey: (NumberKey) -> Void
    private let onFinderHotKey: () -> Void
    private let onManualHotKey: (UUID) -> Void
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var manualHotKeyIDs: [UInt32: UUID] = [:]
    private var handlerRef: EventHandlerRef?

    init(
        onDockHotKey: @escaping (NumberKey) -> Void,
        onFinderHotKey: @escaping () -> Void,
        onManualHotKey: @escaping (UUID) -> Void
    ) {
        self.onDockHotKey = onDockHotKey
        self.onFinderHotKey = onFinderHotKey
        self.onManualHotKey = onManualHotKey
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
        manualShortcuts: [ManualShortcut]
    ) -> String? {
        unregister()

        var errors: [String] = []
        var registeredCombos = Set<HotKeyCombo>()

        if finderShortcutEnabled, let finderError = registerFinderHotKey(registeredCombos: &registeredCombos) {
            errors.append(finderError)
        }

        if modifiers.isEmpty {
            errors.append("Select at least one modifier key.")
        } else if let dockError = registerDockHotKeys(modifiers: modifiers, registeredCombos: &registeredCombos) {
            errors.append(dockError)
        }

        if let manualError = registerManualHotKeys(manualShortcuts, registeredCombos: &registeredCombos) {
            errors.append(manualError)
        }

        return errors.isEmpty ? nil : errors.joined(separator: " ")
    }

    func unregister() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        manualHotKeyIDs.removeAll()
    }

    private func registerFinderHotKey(registeredCombos: inout Set<HotKeyCombo>) -> String? {
        var failures: [String] = []
        let modifiers = UInt32(optionKey)

        for hotKey in Self.finderHotKeys {
            let combo = HotKeyCombo(keyCode: hotKey.keyCode, modifiers: modifiers)
            guard !registeredCombos.contains(combo) else { continue }

            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKey.id)
            let status = RegisterEventHotKey(
                hotKey.keyCode,
                modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )

            if status == noErr, let ref {
                hotKeyRefs.append(ref)
                registeredCombos.insert(combo)
            } else {
                failures.append("\(hotKey.keyCode) (\(status))")
            }
        }

        if failures.isEmpty {
            return nil
        }
        return "Finder shortcut could not be registered for all ₩/` variants: \(failures.joined(separator: ", "))"
    }

    private func registerDockHotKeys(
        modifiers: Set<ShortcutModifier>,
        registeredCombos: inout Set<HotKeyCombo>
    ) -> String? {
        let carbonModifiers = Self.carbonModifiers(for: modifiers)
        var failures: [String] = []

        for key in NumberKey.allCases {
            let combo = HotKeyCombo(keyCode: key.carbonKeyCode, modifiers: carbonModifiers)
            if registeredCombos.contains(combo) {
                failures.append("\(key.displayName) (conflict)")
                continue
            }

            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: UInt32(key.rawValue))
            let status = RegisterEventHotKey(
                key.carbonKeyCode,
                carbonModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )

            if status == noErr, let ref {
                hotKeyRefs.append(ref)
                registeredCombos.insert(combo)
            } else {
                failures.append("\(key.displayName) (\(status))")
            }
        }

        if failures.isEmpty {
            return nil
        }
        return "Some Dock shortcuts could not be registered: \(failures.joined(separator: ", "))"
    }

    private func registerManualHotKeys(
        _ shortcuts: [ManualShortcut],
        registeredCombos: inout Set<HotKeyCombo>
    ) -> String? {
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

            let id = UInt32(1000 + index)
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: id)
            let status = RegisterEventHotKey(
                keyCode,
                carbonModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )

            if status == noErr, let ref {
                hotKeyRefs.append(ref)
                manualHotKeyIDs[id] = shortcut.id
                registeredCombos.insert(combo)
            } else {
                failures.append("\(shortcut.name) (\(status))")
            }
        }

        if failures.isEmpty {
            return nil
        }
        return "Some manual shortcuts could not be registered: \(failures.joined(separator: ", "))"
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

        if Self.finderHotKeyIDs.contains(hotKeyID.id) {
            DispatchQueue.main.async { [onFinderHotKey] in
                onFinderHotKey()
            }
            return noErr
        }

        if let manualShortcutID = manualHotKeyIDs[hotKeyID.id] {
            DispatchQueue.main.async { [onManualHotKey] in
                onManualHotKey(manualShortcutID)
            }
            return noErr
        }

        guard let key = NumberKey(rawValue: Int(hotKeyID.id)) else {
            return noErr
        }

        DispatchQueue.main.async { [onDockHotKey] in
            onDockHotKey(key)
        }
        return noErr
    }

    private struct HotKeyCombo: Hashable {
        let keyCode: UInt32
        let modifiers: UInt32
    }

    private static func carbonModifiers(for modifiers: Set<ShortcutModifier>) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
