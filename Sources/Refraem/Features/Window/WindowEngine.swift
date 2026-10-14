import AppKit

@MainActor
final class WindowEngine {
    static let shared = WindowEngine()

    func perform(_ snap: WindowSnap) {
        guard AXIsProcessTrusted() else {
            promptAccessibility()
            return
        }
        guard let window = AccessibilityWindow.targetWindow() else {
            notify(
                "No window to resize",
                "Click the app you want (Safari, Finder, etc.), then use Refraem again — or use the keyboard shortcut ^⌥→ without opening the menu."
            )
            return
        }
        guard let current = AccessibilityWindow.frame(of: window) else {
            notify("Could not read window", "That window may not allow resizing. Try a normal app window (not full-screen).")
            return
        }

        let visible = AccessibilityWindow.targetVisibleFrame(for: current)
        let target = WindowSnapGeometry.rect(for: snap, in: visible)

        if AccessibilityWindow.setFrame(target, on: window) {
            NSSound.beep()
            return
        }
        notify("Resize failed", "Enable Accessibility for Refraem, then try again.")
    }

    private func promptAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Accessibility access required"
        alert.informativeText =
            "Open System Settings → Privacy & Security → Accessibility and turn on Refraem. Layout shortcuts need this to move other apps’ windows."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func notify(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
