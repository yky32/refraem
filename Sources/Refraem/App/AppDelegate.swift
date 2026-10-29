import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let actions = AppActions()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let slot = NSStatusBar.system.thickness
        statusItem = NSStatusBar.system.statusItem(withLength: slot)
        if let button = statusItem.button {
            button.imageScaling = .scaleProportionallyUpOrDown
            button.image = BrandIcon.menuBarImage()
            button.toolTip = Brand.name
        }
        MenuController.shared.attach(to: statusItem, actions: actions)
        HotkeyStore.shared.onChange = { [actions] in
            actions.registerGlobalHotkeys()
        }
        actions.registerGlobalHotkeys()
        WindowEngine.shared.consumePendingSnap()
        LayoutReview.startIfRequested()
    }

    func applicationWillTerminate(_ notification: Notification) {
        actions.unregisterGlobalHotkeys()
    }
}
