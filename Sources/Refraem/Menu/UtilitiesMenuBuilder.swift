import AppKit

enum UtilitiesMenuBuilder {
    @MainActor
    static func makeMenu(controller: MenuController) -> NSMenu {
        let menu = NSMenu()

        menu.addItem(sectionHeader("Layout"))
        for snap in [
            WindowSnap.leftHalf, .rightHalf, .centerHalf, .topHalf, .bottomHalf,
        ] {
            menu.addItem(item(for: .window(snap), controller: controller))
        }
        menu.addItem(.separator())
        for snap in [WindowSnap.topLeft, .topRight, .bottomLeft, .bottomRight] {
            menu.addItem(item(for: .window(snap), controller: controller))
        }
        menu.addItem(.separator())
        for snap in [
            WindowSnap.firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds,
        ] {
            menu.addItem(item(for: .window(snap), controller: controller))
        }
        menu.addItem(.separator())
        for snap in [
            WindowSnap.maximize, .almostMaximize, .maximizeHeight, .larger, .smaller, .center, .restore,
        ] {
            menu.addItem(item(for: .window(snap), controller: controller))
        }
        menu.addItem(.separator())
        menu.addItem(item(for: .window(.nextDisplay), controller: controller))
        menu.addItem(item(for: .window(.previousDisplay), controller: controller))

        menu.addItem(.separator())
        menu.addItem(sectionHeader("Capture"))
        menu.addItem(item(for: .capture(.screen), controller: controller))
        menu.addItem(item(for: .capture(.area), controller: controller))
        menu.addItem(item(for: .capture(.scrolling), controller: controller))
        menu.addItem(item(for: .capture(.recognizeTextOrQR), controller: controller))

        menu.addItem(.separator())
        menu.addItem(sectionHeader("Record"))
        if RecordingEngine.shared.isRecording {
            menu.addItem(item(for: .record(.stop), controller: controller))
        } else {
            menu.addItem(item(for: .record(.screen), controller: controller))
            menu.addItem(item(for: .record(.area), controller: controller))
        }

        menu.addItem(.separator())
        let launch = NSMenuItem(
            title: "Launch at Startup",
            action: #selector(MenuController.toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launch.target = controller
        launch.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launch)

        let settings = item(for: .openSettings, controller: controller, title: "Settings…")
        settings.keyEquivalent = ","
        settings.keyEquivalentModifierMask = .command
        menu.addItem(settings)
        menu.addItem(item(for: .quit, controller: controller, title: "Quit"))

        return menu
    }

    @MainActor
    private static func item(
        for action: UtilityAction,
        controller: MenuController,
        title: String? = nil
    ) -> NSMenuItem {
        let tag = controller.register(action: action)
        let item = NSMenuItem(
            title: title ?? menuTitle(for: action),
            action: #selector(MenuController.menuItemSelected(_:)),
            keyEquivalent: ""
        )
        item.target = controller
        item.tag = tag
        if case .window(let snap) = action, let image = NSImage(systemSymbolName: snap.symbolName, accessibilityDescription: snap.menuTitle) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            item.image = image
        }
        applyKeyEquivalent(to: item, action: action)
        return item
    }

    private static func menuTitle(for action: UtilityAction) -> String {
        switch action {
        case .window(let snap): snap.menuTitle
        case .capture(let mode): mode.menuTitle
        case .record(let mode): mode.menuTitle
        case .openSettings: "Settings…"
        case .quit: "Quit"
        }
    }

    private static func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @MainActor
    private static func applyKeyEquivalent(to item: NSMenuItem, action: UtilityAction) {
        guard let hotkey = HotkeyStore.shared.binding(for: action) else { return }
        item.keyEquivalent = hotkey.menuKeyEquivalent
        item.keyEquivalentModifierMask = hotkey.nsModifierFlags
    }
}

private extension GlobalHotkey {
    var menuKeyEquivalent: String {
        if let character, !character.isEmpty { return character }
        switch keyCode {
        case 123: return "\u{F702}"
        case 124: return "\u{F703}"
        case 125: return "\u{F701}"
        case 126: return "\u{F700}"
        case 36: return "\r"
        case 51: return "\u{08}"
        default: return ""
        }
    }
}
