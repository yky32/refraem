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
        menu.addItem(sectionHeader("Capture"))
        menu.addItem(item(for: .capture(.screen), controller: controller))
        menu.addItem(item(for: .capture(.area), controller: controller))
        let scroll = item(for: .capture(.scrolling), controller: controller)
        scroll.isEnabled = false
        scroll.toolTip = "Coming in a later milestone"
        menu.addItem(scroll)
        menu.addItem(item(for: .capture(.recognizeTextOrQR), controller: controller))

        menu.addItem(.separator())
        menu.addItem(sectionHeader("Record"))
        for title in ["Record Screen", "Record Area"] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.toolTip = "Coming soon"
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(item(for: .openSettings, controller: controller, title: "Settings…"))
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
        applyKeyEquivalent(to: item, action: action)
        return item
    }

    private static func menuTitle(for action: UtilityAction) -> String {
        switch action {
        case .window(let snap): snap.menuTitle
        case .capture(let mode): mode.menuTitle
        case .openSettings: "Settings…"
        case .quit: "Quit"
        }
    }

    private static func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private static func applyKeyEquivalent(to item: NSMenuItem, action: UtilityAction) {
        guard let hotkey = DefaultHotkeys.bindings[action] else { return }
        if let char = hotkey.character {
            item.keyEquivalent = String(char)
        } else {
            item.keyEquivalent = hotkey.arrowKeyEquivalent
        }
        item.keyEquivalentModifierMask = hotkey.nsModifierFlags
    }
}

private extension GlobalHotkey {
    var arrowKeyEquivalent: String {
        switch keyCode {
        case 123: "\u{F702}"
        case 124: "\u{F703}"
        case 125: "\u{F701}"
        case 126: "\u{F700}"
        default: ""
        }
    }
}
