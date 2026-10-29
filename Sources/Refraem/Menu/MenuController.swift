import AppKit

/// Tag-based menu dispatch (reliable) + remembers frontmost app before menu opens.
@MainActor
final class MenuController: NSObject {
    static let shared = MenuController()

    private weak var actions: AppActions?
    private var menu: NSMenu!
    private var tagToAction: [Int: UtilityAction] = [:]
    private var nextTag = 1

    func attach(to statusItem: NSStatusItem, actions: AppActions) {
        self.actions = actions
        menu = UtilitiesMenuBuilder.makeMenu(controller: self)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(showMenu(_:))
        // Do not assign statusItem.menu — manual popup keeps the user's app focused.
    }

    func register(action: UtilityAction) -> Int {
        let tag = nextTag
        nextTag += 1
        tagToAction[tag] = action
        return tag
    }

    @objc private func showMenu(_ sender: AnyObject?) {
     WindowTargetStore.shared.rememberFrontmostIfOtherApp()
     guard let button = sender as? NSStatusBarButton else { return }
     tagToAction.removeAll()
     nextTag = 1
     menu = UtilitiesMenuBuilder.makeMenu(controller: self)
     menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
 }

    @objc func menuItemSelected(_ sender: NSMenuItem) {
        guard let action = tagToAction[sender.tag] else { return }
        actions?.handle(action)
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let next = !LaunchAtLogin.isEnabled
        if LaunchAtLogin.setEnabled(next) {
            sender.state = next ? .on : .off
        }
    }
}
