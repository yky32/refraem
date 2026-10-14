import AppKit
import ApplicationServices

@MainActor
enum AccessibilityWindow {
    static func targetWindow() -> AXUIElement? {
        if let pid = WindowTargetStore.shared.targetApplicationPID() {
            if let window = focusedOrMainWindow(inProcess: pid) {
                return window
            }
        }
        return focusedWindowViaSystem()
    }

    private static func focusedWindowViaSystem() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var appRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString, &appRef) == .success,
              let appRef
        else { return nil }

        let app = appRef as! AXUIElement
        return focusedOrMainWindow(in: app)
    }

    private static func focusedOrMainWindow(inProcess pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        return focusedOrMainWindow(in: app)
    }

    private static func focusedOrMainWindow(in app: AXUIElement) -> AXUIElement? {
        var windowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
           let windowRef
        {
            return (windowRef as! AXUIElement)
        }
        windowRef = nil
        if AXUIElementCopyAttributeValue(app, kAXMainWindowAttribute as CFString, &windowRef) == .success,
           let windowRef
        {
            return (windowRef as! AXUIElement)
        }
        return nil
    }

    static func frame(of window: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionRef, let sizeRef
        else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        else { return nil }

        return CGRect(origin: point, size: size)
    }

    static func setFrame(_ frame: CGRect, on window: AXUIElement) -> Bool {
        exitFullScreenIfNeeded(window)

        var size = frame.size
        var position = frame.origin
        guard let sizeValue = AXValueCreate(.cgSize, &size),
              let positionValue = AXValueCreate(.cgPoint, &position)
        else { return false }

        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        let posResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        if sizeResult == .success, posResult == .success { return true }

        // Retry opposite order (some apps are picky).
        _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let sizeRetry = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        return sizeRetry == .success
    }

    private static func exitFullScreenIfNeeded(_ window: AXUIElement) {
        var value: CFTypeRef?
        let fullScreenAttr = "AXFullScreen" as CFString
        guard AXUIElementCopyAttributeValue(window, fullScreenAttr, &value) == .success,
              let number = value as? NSNumber,
              number.boolValue
        else { return }
        AXUIElementSetAttributeValue(window, fullScreenAttr, kCFBooleanFalse!)
    }

    static func targetVisibleFrame(for windowFrame: CGRect) -> CGRect {
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        return screen?.visibleFrame ?? NSScreen.main!.visibleFrame
    }
}
