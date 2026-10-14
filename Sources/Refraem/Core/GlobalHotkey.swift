import AppKit
import Carbon

struct GlobalHotkey: Hashable {
    let keyCode: UInt16
    let modifiers: [Modifier]
    let character: Character?

    init(keyCode: UInt16, modifiers: [Modifier], character: Character? = nil) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.character = character
    }

    enum Modifier: Hashable {
        case control, option, command, shift
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
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                hotKeyRefs.append(ref)
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
            DispatchQueue.main.async {
                Task { @MainActor in
                    GlobalHotkeyRegistry.shared.dispatchHotKey(id: actionID)
                }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }

    private func dispatchHotKey(id: UInt32) {
        guard let action = actionByHotKeyID[id] else { return }
        handler?(action)
    }
}
