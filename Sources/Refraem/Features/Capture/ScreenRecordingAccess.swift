import AppKit
@preconcurrency import ScreenCaptureKit

/// Screen Recording is bound to this signed copy. After a rebuild, Settings can still show an old grant while capture returns declined until the switch is flipped and Refraem relaunches.
@MainActor
enum ScreenRecordingAccess {
    private static var didRequestSystemPrompt = false
    private static var didShowHelp = false
    private static var watchingGrant = false

    static func ensure() async -> Bool {
        if await canCapture() {
            LayoutLog.write("capture-ok")
            return true
        }

        if !didRequestSystemPrompt {
            didRequestSystemPrompt = true
            LayoutLog.write("capture-request-system")
            let allowed = CGRequestScreenCaptureAccess()
            LayoutLog.write("capture-request-result=\(allowed)")
            // Allow appears while this returns. Give a short window, then help — do not block for 20s.
            if allowed {
                LayoutLog.write("capture-granted-after-request")
                return true
            }
            if await waitUntilCaptureWorks(seconds: 4) {
                LayoutLog.write("capture-granted-after-wait")
                return true
            }
        }

        if await canCapture() { return true }
        explain()
        watchForGrant()
        return await canCapture()
    }

    static func canCapture() async -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            LayoutLog.write("capture-denied \(error.localizedDescription)")
            return false
        }
    }

    static func statusLabel() async -> String {
        await canCapture() ? "Allowed" : "Needs allow"
    }

    private static func waitUntilCaptureWorks(seconds: Double) async -> Bool {
        let steps = Int(seconds / 0.35)
        for _ in 0..<max(1, steps) {
            if await canCapture() { return true }
            try? await Task.sleep(nanoseconds: 350_000_000)
        }
        return false
    }

    private static func explain() {
        if !didShowHelp {
            didShowHelp = true
            let alert = NSAlert()
            alert.messageText = "Allow Refraem to capture the screen"
            alert.informativeText =
                "Open Screen Recording, find Refraem, turn it OFF then ON. Come back and click Relaunch. Capture will work after that."
            alert.addButton(withTitle: "Open Screen Recording")
            alert.addButton(withTitle: "Relaunch")
            alert.addButton(withTitle: "Later")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                openSettings()
            case .alertSecondButtonReturn:
                relaunch()
            default:
                break
            }
        } else {
            openSettings()
        }
    }

    private static func watchForGrant() {
        guard !watchingGrant else { return }
        watchingGrant = true
        Task {
            for _ in 0..<90 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if await canCapture() {
                    LayoutLog.write("capture-granted-relaunch")
                    watchingGrant = false
                    relaunch()
                    return
                }
            }
            watchingGrant = false
        }
    }

    private static func openSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        ]
        for raw in urls {
            guard let url = URL(string: raw), NSWorkspace.shared.open(url) else { continue }
            return
        }
    }

    private static func relaunch() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
