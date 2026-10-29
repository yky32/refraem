import Foundation

/// Saved shortcut overrides. Missing entries keep the built-in defaults.
@MainActor
final class HotkeyStore {
    static let shared = HotkeyStore()

    var onChange: (() -> Void)?

    private let defaultsKey = "refraem.hotkeys"
    private var overrides: [String: GlobalHotkey] = [:]
    private var disabled: Set<String> = []

    private init() {
        load()
    }

    func binding(for action: UtilityAction) -> GlobalHotkey? {
        let id = action.storageID
        if disabled.contains(id) { return nil }
        if let override = overrides[id] { return override }
        return DefaultHotkeys.bindings[action]
    }

    var bindings: [UtilityAction: GlobalHotkey] {
        var result: [UtilityAction: GlobalHotkey] = [:]
        for action in Self.customizable {
            if let hotkey = binding(for: action) {
                result[action] = hotkey
            }
        }
        return result
    }

    func set(_ hotkey: GlobalHotkey?, for action: UtilityAction) {
        let id = action.storageID
        if let hotkey {
            for other in Self.customizable where other != action {
                guard let existing = binding(for: other), existing.sameCombo(as: hotkey) else { continue }
                disabled.insert(other.storageID)
                overrides.removeValue(forKey: other.storageID)
            }
            overrides[id] = hotkey
            disabled.remove(id)
        } else {
            overrides.removeValue(forKey: id)
            disabled.insert(id)
        }
        save()
        onChange?()
    }

    func reset() {
        overrides = [:]
        disabled = []
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        onChange?()
    }

    static let groups: [(title: String, actions: [UtilityAction])] = [
        ("Layout", [
            .window(.leftHalf), .window(.rightHalf), .window(.centerHalf),
            .window(.topHalf), .window(.bottomHalf),
            .window(.topLeft), .window(.topRight), .window(.bottomLeft), .window(.bottomRight),
            .window(.firstThird), .window(.centerThird), .window(.lastThird),
            .window(.firstTwoThirds), .window(.lastTwoThirds),
            .window(.maximize), .window(.almostMaximize), .window(.maximizeHeight),
            .window(.larger), .window(.smaller), .window(.center), .window(.restore),
            .window(.nextDisplay), .window(.previousDisplay),
        ]),
        ("Capture", [
            .capture(.screen), .capture(.area), .capture(.scrolling), .capture(.recognizeTextOrQR),
        ]),
        ("Record", [
            .record(.screen), .record(.area),
        ]),
    ]

    static var customizable: [UtilityAction] {
        groups.flatMap(\.actions)
    }

    private struct Saved: Codable {
        var overrides: [String: GlobalHotkey]
        var disabled: [String]
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode(Saved.self, from: data)
        else { return }
        overrides = saved.overrides
        disabled = Set(saved.disabled)
    }

    private func save() {
        let saved = Saved(overrides: overrides, disabled: Array(disabled))
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

extension UtilityAction {
    var storageID: String {
        switch self {
        case .window(let snap): "window.\(snap.rawValue)"
        case .capture(let mode): "capture.\(mode.rawValue)"
        case .record(let mode): "record.\(mode.rawValue)"
        case .openSettings: "settings"
        case .quit: "quit"
        }
    }

    var settingsTitle: String {
        switch self {
        case .window(let snap): snap.menuTitle
        case .capture(let mode): mode.menuTitle
        case .record(let mode): mode.menuTitle
        case .openSettings: "Settings…"
        case .quit: "Quit"
        }
    }
}
