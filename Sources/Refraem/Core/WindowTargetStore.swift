import AppKit

/// Remembers which app to resize when the menu bar menu is used (Refraem must not steal focus).
@MainActor
final class WindowTargetStore {
    static let shared = WindowTargetStore()
    private var rememberedPID: pid_t?

    func rememberFrontmostIfOtherApp() {
        let me = ProcessInfo.processInfo.processIdentifier
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != me
        else { return }
        rememberedPID = app.processIdentifier
    }

    func targetApplicationPID() -> pid_t? {
        let me = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication?.processIdentifier,
           front != me
        {
            return front
        }
        return rememberedPID
    }

    func clear() {
        rememberedPID = nil
    }
}
