import AppKit

/// Runs every layout action against a throwaway window and writes `/tmp/refraem-review-report.txt`.
/// Trigger by creating `/tmp/refraem-review` before launch.
@MainActor
enum LayoutReview {
    private static let flagPath = "/tmp/refraem-review"
    private static let reportPath = "/tmp/refraem-review-report.txt"

    static func startIfRequested() {
        guard FileManager.default.fileExists(atPath: flagPath) else { return }
        try? FileManager.default.removeItem(atPath: flagPath)
        Task { await run() }
    }

    private static let steps: [WindowSnap] = [
        .maximize,
        .leftHalf,
        .maximize,
        .rightHalf,
        .maximize,
        .bottomHalf,
        .maximize,
        .topHalf,
        .maximize,
        .topLeft,
        .topRight,
        .bottomLeft,
        .bottomRight,
        .firstThird,
        .centerThird,
        .lastThird,
        .firstTwoThirds,
        .lastTwoThirds,
        .centerHalf,
        .almostMaximize,
        .maximizeHeight,
        .center,
        .smaller,
        .larger,
        .restore,
    ]

    private static func run() async {
        WindowEngine.shared.suppressAlerts = true
        defer { WindowEngine.shared.suppressAlerts = false }

        let textEditWasRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.TextEdit"
        }
        let scriptError = runAppleScript("""
        tell application "TextEdit"
            activate
            make new document
        end tell
        """)
        try? await Task.sleep(nanoseconds: 700_000_000)

        guard let textEdit = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.TextEdit"
        }) else {
            write(["FAIL setup: TextEdit did not launch \(scriptError ?? "")"])
            return
        }
        WindowTargetStore.shared.pin(textEdit.processIdentifier)
        defer {
            WindowTargetStore.shared.pin(nil)
            if textEditWasRunning {
                _ = runAppleScript("tell application \"TextEdit\" to close front document saving no")
            } else {
                textEdit.terminate()
            }
        }

        guard AccessibilityWindow.targetWindow() != nil else {
            write(["FAIL setup: no window to resize denied=\(AccessibilityWindow.accessDenied) \(scriptError ?? "")"])
            return
        }

        var lines = ["layout review"]
        var previous = AccessibilityWindow.frame(of: AccessibilityWindow.targetWindow()!)
        for snap in steps {
            guard let before = AccessibilityWindow.frame(of: AccessibilityWindow.targetWindow()!) else {
                lines.append("FAIL \(snap.menuTitle): could not read window")
                continue
            }
            let expected = expectedFrame(for: snap, before: before, restore: previous)
            WindowEngine.shared.perform(snap)
            let actual = await wait(for: expected, timeout: 1.6)
            if let expected, let actual, close(actual, expected) {
                lines.append("PASS \(snap.menuTitle) \(rect(actual))")
            } else if expected == nil, let actual, close(actual, before) {
                lines.append("PASS \(snap.menuTitle) unchanged")
            } else {
                lines.append("FAIL \(snap.menuTitle) expected \(expected.map(rect) ?? "nil") actual \(actual.map(rect) ?? "nil")")
            }
            previous = before
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        write(lines)
    }

    private static func expectedFrame(for snap: WindowSnap, before: CGRect, restore: CGRect?) -> CGRect? {
        switch snap {
        case .restore:
            return restore
        case .nextDisplay:
            return AccessibilityWindow.frame(moving: before, displaysBy: 1)
        case .previousDisplay:
            return AccessibilityWindow.frame(moving: before, displaysBy: -1)
        default:
            let visible = AccessibilityWindow.targetVisibleFrame(for: before)
            return WindowSnapGeometry.rect(for: snap, current: before, in: visible)
        }
    }

    private static func wait(for expected: CGRect?, timeout: TimeInterval) async -> CGRect? {
        let deadline = Date().addingTimeInterval(timeout)
        var latest = AccessibilityWindow.targetWindow().flatMap { AccessibilityWindow.frame(of: $0) }
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
            latest = AccessibilityWindow.targetWindow().flatMap { AccessibilityWindow.frame(of: $0) }
            if let expected, let latest, close(latest, expected) { return latest }
        }
        return latest
    }

    private static func close(_ actual: CGRect, _ target: CGRect) -> Bool {
        abs(actual.minX - target.minX) < 24
            && abs(actual.minY - target.minY) < 24
            && abs(actual.width - target.width) < 36
            && abs(actual.height - target.height) < 36
    }

    private static func rect(_ value: CGRect) -> String {
        String(format: "(%.0f,%.0f %.0fx%.0f)", value.minX, value.minY, value.width, value.height)
    }

    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error?["NSAppleScriptErrorMessage"] as? String
    }

    private static func write(_ lines: [String]) {
        let text = lines.joined(separator: "\n") + "\n"
        try? text.write(toFile: reportPath, atomically: true, encoding: .utf8)
        LayoutLog.write("review-done")
    }
}
