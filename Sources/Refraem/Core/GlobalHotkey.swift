import AppKit
import Carbon

struct GlobalHotkey: Hashable, Codable {
    let keyCode: UInt16
    let modifiers: [Modifier]
    let character: String?

    init(keyCode: UInt16, modifiers: [Modifier], character: String? = nil) {
        self.keyCode = keyCode
        self.modifiers = Self.ordered(modifiers)
        self.character = character
    }

    init(event: NSEvent) {
        var modifiers: [Modifier] = []
        let flags = event.modifierFlags
        if flags.contains(.control) { modifiers.append(.control) }
        if flags.contains(.option) { modifiers.append(.option) }
        if flags.contains(.shift) { modifiers.append(.shift) }
        if flags.contains(.command) { modifiers.append(.command) }
        let raw = event.charactersIgnoringModifiers?.lowercased()
        let printable = (raw?.count == 1 && event.keyCode >= 0) ? raw : nil
        let named = [123, 124, 125, 126, 36, 48, 49, 51, 53, 117].contains(Int(event.keyCode))
        self.init(keyCode: event.keyCode, modifiers: modifiers, character: named ? nil : printable)
    }

    enum Modifier: String, Hashable, Codable {
        case control, option, command, shift
    }

    func sameCombo(as other: GlobalHotkey) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }

    var shortcutLabel: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        text += keyTitle
        return text
    }

    private var keyTitle: String {
        switch keyCode {
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 117: return "⌦"
        default:
            if let character, !character.isEmpty { return character.uppercased() }
            return "Key \(keyCode)"
        }
    }

    private static func ordered(_ modifiers: [Modifier]) -> [Modifier] {
        let order: [Modifier] = [.control, .option, .shift, .command]
        return order.filter { modifiers.contains($0) }
    }

    var nsModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        for m in modifiers {
            switch m {
            case .control: flags.insert(.control)
            case .option: flags.insert(.option)
            case .command: flags.insert(.command)
            case .shift: flags.insert(.shift)
            }
        }
        return flags
    }

    var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        for m in modifiers {
            switch m {
            case .control: flags |= UInt32(controlKey)
            case .option: flags |= UInt32(optionKey)
            case .command: flags |= UInt32(cmdKey)
            case .shift: flags |= UInt32(shiftKey)
            }
        }
        return flags
    }
}

private enum HotKeySignature {
    static let osType: OSType = 0x5246_524D // "RFRM"
}

@MainActor
final class GlobalHotkeyRegistry {
    static let shared = GlobalHotkeyRegistry()

    private var handler: ((UtilityAction) -> Void)?
    private var actionByHotKeyID: [UInt32: UtilityAction] = [:]
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private var nextID: UInt32 = 1
    private var lastFire: (id: UInt32, time: TimeInterval)?
    private static var installed = false

    func register(defaults: [UtilityAction: GlobalHotkey], handler: @escaping (UtilityAction) -> Void) {
        self.handler = handler
        uninstallHotKeys()
        installEventHandlerIfNeeded()

        for (action, hotkey) in defaults {
            let id = nextID
            nextID += 1
            actionByHotKeyID[id] = action

            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: HotKeySignature.osType, id: id)
            let status = RegisterEventHotKey(
                UInt32(hotkey.keyCode),
                hotkey.carbonModifiers,
                hotKeyID,
                GetEventDispatcherTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                hotKeyRefs.append(ref)
            } else {
                LayoutLog.write("hotkey-register-failed id=\(id) key=\(hotkey.keyCode) mods=\(hotkey.carbonModifiers) status=\(status)")
            }
        }
    }

    func unregisterAll() {
        handler = nil
        uninstallHotKeys()
    }

    private func uninstallHotKeys() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        actionByHotKeyID.removeAll()
        nextID = 1
    }

    private func installEventHandlerIfNeeded() {
        guard !Self.installed else { return }
        Self.installed = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard err == noErr else { return err }
            let actionID = hotKeyID.id
            LayoutLog.write("hotkey-fired id=\(actionID)")
            DispatchQueue.main.async {
                Task { @MainActor in
                    GlobalHotkeyRegistry.shared.dispatchHotKey(id: actionID)
                }
            }
            return noErr
        }

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        LayoutLog.write("hotkey-handler status=\(status)")
    }

    private func dispatchHotKey(id: UInt32) {
        let now = ProcessInfo.processInfo.systemUptime
        if let lastFire, lastFire.id == id, now - lastFire.time < 0.75 {
            return
        }
        lastFire = (id, now)
        guard let action = actionByHotKeyID[id] else { return }
        handler?(action)
    }
}
