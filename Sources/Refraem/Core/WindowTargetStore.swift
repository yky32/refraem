import AppKit

/// Remembers which app to resize when the menu bar menu is used (Refraem must not steal focus).
@MainActor
final class WindowTargetStore {
    static let shared = WindowTargetStore()
    private var rememberedPID: pid_t?
    private var pinnedPID: pid_t?

    func remember(_ pid: pid_t) {
        guard pid > 0, pid != ProcessInfo.processInfo.processIdentifier else { return }
        rememberedPID = pid
    }

    func rememberFrontmostIfOtherApp() {
        guard let app = userFacingApplication() else { return }
        rememberedPID = app.processIdentifier
    }

    /// Forces the next snaps onto one process, including Refraem itself during an automatic review.
    func pin(_ pid: pid_t?) {
        pinnedPID = pid
    }

    func targetApplicationPID() -> pid_t? {
        if let pinnedPID, pinnedPID > 0 { return pinnedPID }
        if let app = userFacingApplication() {
            return app.processIdentifier
        }
        return rememberedPID
    }

    /// The menu-bar owner is the app the user is actually in. `frontmostApplication` can be
    /// `loginwindow` while Cursor still owns the menu bar, and resizing that does nothing.
    private func userFacingApplication() -> NSRunningApplication? {
        let me = ProcessInfo.processInfo.processIdentifier
        let candidates = [
            NSWorkspace.shared.menuBarOwningApplication,
            NSWorkspace.shared.frontmostApplication,
        ]
        for app in candidates {
            guard let app, app.processIdentifier != me else { continue }
            if app.bundleIdentifier == "com.apple.loginwindow" { continue }
            return app
        }
        return nil
    }

    func clear() {
        rememberedPID = nil
    }
}
