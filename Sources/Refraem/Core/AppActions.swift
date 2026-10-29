import AppKit

/// Routes menu items and (later) global hotkeys to window/capture engines.
@MainActor
final class AppActions {
    func registerGlobalHotkeys() {
        GlobalHotkeyRegistry.shared.register(defaults: HotkeyStore.shared.bindings, handler: handle(_:))
    }

    func unregisterGlobalHotkeys() {
        GlobalHotkeyRegistry.shared.unregisterAll()
    }

    func handle(_ action: UtilityAction) {
        switch action {
        case .window(let snap):
            WindowEngine.shared.perform(snap)
        case .capture(let mode):
            CaptureEngine.shared.perform(mode)
        case .record(let mode):
            switch mode {
            case .screen: RecordingEngine.shared.toggleScreen()
            case .area: RecordingEngine.shared.toggleArea()
            case .stop: RecordingEngine.shared.stop()
            }
        case .openSettings:
            SettingsWindowController.shared.show()
        case .quit:
            NSApp.terminate(nil)
        }
    }
}
