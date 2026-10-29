import AppKit

@MainActor
final class WindowEngine {
    static let shared = WindowEngine()
    private static let pendingSnapKey = "refraem.pendingSnap"
    private static let pendingPIDKey = "refraem.pendingPID"

    private var restoreFrames: [String: CGRect] = [:]
    private var didAskAccessibility = false
    private var didOpenSettings = false
    private var watchingGrant = false
    var suppressAlerts = false

    func perform(_ snap: WindowSnap) {
        perform(snap, allowRetry: true)
    }

    private func perform(_ snap: WindowSnap, allowRetry: Bool) {
        let front = NSWorkspace.shared.frontmostApplication
        let menu = NSWorkspace.shared.menuBarOwningApplication
        LayoutLog.write("perform \(snap) front=\(front?.localizedName ?? "?") menu=\(menu?.localizedName ?? "?") retry=\(allowRetry)")
        guard let window = AccessibilityWindow.targetWindow() else {
            if AccessibilityWindow.accessDenied {
                LayoutLog.write("accessibility-api-disabled")
                requestAccessibility(for: snap)
                return
            }
            if allowRetry {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.perform(snap, allowRetry: false)
                }
                return
            }
            notify(
                "No window to resize",
                "Click the app you want, then use Refraem again — or use a keyboard shortcut without opening the menu."
            )
            return
        }
        guard let current = AccessibilityWindow.frame(of: window) else {
            notify("Could not read window", "That window may not allow resizing. Try a normal app window.")
            return
        }

        let visible = AccessibilityWindow.targetVisibleFrame(for: current)
        let target: CGRect?
        switch snap {
        case .restore:
            target = restoreFrames[AccessibilityWindow.identity(of: window)]
            if target == nil {
                notify("Nothing to restore", "Snap or resize a window first, then choose Restore.")
                return
            }
        case .nextDisplay:
            target = AccessibilityWindow.frame(moving: current, displaysBy: 1)
        case .previousDisplay:
            target = AccessibilityWindow.frame(moving: current, displaysBy: -1)
        default:
            target = WindowSnapGeometry.rect(for: snap, current: current, in: visible)
        }

        guard let target else {
            LayoutLog.write("no-target current=\(current)")
            return
        }
        LayoutLog.write("current=\(current) target=\(target)")
        if framesMatch(current, target) {
            LayoutLog.write("already-there")
            return
        }

        let key = AccessibilityWindow.identity(of: window)
        let previous = restoreFrames[key]
        restoreFrames[key] = current

        if AccessibilityWindow.setFrame(target, on: window) {
            return
        }
        restoreFrames[key] = previous
        notify("Resize failed", "Enable Accessibility for Refraem, then try again.")
    }

    private func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 1
            && abs(a.minY - b.minY) < 1
            && abs(a.width - b.width) < 1
            && abs(a.height - b.height) < 1
    }

    func consumePendingSnap() {
        let defaults = UserDefaults.standard
        guard let raw = defaults.string(forKey: Self.pendingSnapKey),
              let snap = WindowSnap(rawValue: raw)
        else { return }
        let pid = pid_t(defaults.integer(forKey: Self.pendingPIDKey))
        defaults.removeObject(forKey: Self.pendingSnapKey)
        defaults.removeObject(forKey: Self.pendingPIDKey)
        if pid > 0 {
            WindowTargetStore.shared.remember(pid)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.perform(snap)
        }
    }

    /// The system dialog is what actually adds Refraem to Accessibility. A custom alert on every item never grants it.
    private func requestAccessibility(for snap: WindowSnap) {
        let defaults = UserDefaults.standard
        defaults.set(snap.rawValue, forKey: Self.pendingSnapKey)
        if let pid = WindowTargetStore.shared.targetApplicationPID() {
            defaults.set(Int(pid), forKey: Self.pendingPIDKey)
        }
        if !didAskAccessibility {
            didAskAccessibility = true
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            LayoutLog.write("accessibility-prompt")
        } else if !didOpenSettings {
            didOpenSettings = true
            openAccessibilitySettings()
            LayoutLog.write("accessibility-open-settings")
        }
        watchForGrant()
    }

    private func watchForGrant() {
        guard !watchingGrant else { return }
        watchingGrant = true
        pollGrant(attempt: 0)
    }

    private func pollGrant(attempt: Int) {
        guard watchingGrant, attempt < 90 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            if AXIsProcessTrusted() {
                self.watchingGrant = false
                LayoutLog.write("accessibility-granted-relaunch")
                self.relaunch()
            } else {
                self.pollGrant(attempt: attempt + 1)
            }
        }
    }

    private func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for raw in urls {
            guard let url = URL(string: raw), NSWorkspace.shared.open(url) else { continue }
            return
        }
    }

    private func relaunch() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    private func notify(_ title: String, _ message: String) {
        if suppressAlerts {
            LayoutLog.write("alert \(title)")
            return
        }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
