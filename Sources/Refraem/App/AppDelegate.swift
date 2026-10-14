import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let actions = AppActions()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = BrandIcon.menuBarImage()
            button.toolTip = Brand.name
        }
        MenuController.shared.attach(to: statusItem, actions: actions)
        actions.registerGlobalHotkeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        actions.unregisterGlobalHotkeys()
    }
}
