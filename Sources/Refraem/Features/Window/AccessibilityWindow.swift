import AppKit
import ApplicationServices

/// Accessibility frames use the top-left of the primary display, y down.
/// `NSScreen` uses the bottom-left of that display, y up. Callers of this type always see Cocoa frames.
@MainActor
enum AccessibilityWindow {
    static var accessDenied = false

    static func targetWindow() -> AXUIElement? {
        accessDenied = false
        if let pid = WindowTargetStore.shared.targetApplicationPID() {
            if let window = window(inProcess: pid) {
                return window
            }
        }
        return windowViaFocusedApplication()
    }

    static func frame(of window: AXUIElement) -> CGRect? {
        guard let raw = rawFrame(of: window) else { return nil }
        return cocoaFrame(fromAX: raw)
    }

    static func setFrame(_ frame: CGRect, on window: AXUIElement) -> Bool {
        exitFullScreenIfNeeded(window)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)

        let ax = axFrame(fromCocoa: frame)
        let visible = screen(containing: frame)?.visibleFrame
        let anchorBottom = visible.map {
            abs(frame.minY - $0.minY) < 8 && frame.height + 24 < $0.height
        } ?? false
        guard commit(ax, on: window, anchorBottom: anchorBottom) else {
            LayoutLog.write("set-failed ax=\(rectString(ax))")
            return false
        }
        if let actual = rawFrame(of: window) {
            LayoutLog.write("set ax=\(rectString(ax)) actual=\(rectString(actual))")
        }
        return true
    }

    static func targetVisibleFrame(for windowFrame: CGRect) -> CGRect {
        screen(containing: windowFrame)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
    }

    static func screen(containing windowFrame: CGRect) -> NSScreen? {
        let hits = NSScreen.screens.map { screen in
            (screen, intersectionArea(screen.frame, windowFrame))
        }
        if let best = hits.max(by: { $0.1 < $1.1 }), best.1 > 1 {
            return best.0
        }
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
    }

    /// Moves `windowFrame` onto the display `step` screens away (+1 next, −1 previous), wrapping around.
    static func frame(moving windowFrame: CGRect, displaysBy step: Int) -> CGRect? {
        let screens = NSScreen.screens.sorted {
            if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
            return $0.frame.minY < $1.frame.minY
        }
        guard screens.count > 1,
              let current = screen(containing: windowFrame),
              let index = screens.firstIndex(where: { $0 === current })
        else { return nil }

        let nextIndex = (index + step + screens.count) % screens.count
        let from = current.visibleFrame
        let to = screens[nextIndex].visibleFrame
        return WindowSnapGeometry.placed(windowFrame, from: from, onto: to)
    }

    static func identity(of window: AXUIElement) -> String {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let title = stringAttribute(window, kAXTitleAttribute as String) ?? ""
        return "\(pid)|\(title)"
    }

    // MARK: - Finding a window

    private static func windowViaFocusedApplication() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        guard let app = copyElement(system, kAXFocusedApplicationAttribute as String) else { return nil }
        return window(in: app)
    }

    private static func window(inProcess pid: pid_t) -> AXUIElement? {
        window(in: AXUIElementCreateApplication(pid))
    }

    private static func window(in app: AXUIElement) -> AXUIElement? {
        prepare(app)

        if let focused = copyElement(app, kAXFocusedUIElementAttribute as String),
           let window = windowAncestor(of: focused),
           isResizableWindow(window)
        {
            LayoutLog.write("picked focused-ui \(describe(window))")
            return window
        }
        if let focused = copyElement(app, kAXFocusedWindowAttribute as String),
           let window = windowAncestor(of: focused),
           isResizableWindow(window)
        {
            LayoutLog.write("picked focused-window \(describe(window))")
            return window
        }
        if let main = copyElement(app, kAXMainWindowAttribute as String),
           let window = windowAncestor(of: main),
           isResizableWindow(window)
        {
            LayoutLog.write("picked main \(describe(window))")
            return window
        }

        var pool = copyElements(app, kAXWindowsAttribute as String)
        pool.append(contentsOf: copyElements(app, kAXChildrenAttribute as String).filter { role(of: $0) == (kAXWindowRole as String) })
        if let best = bestWindow(from: pool) {
            LayoutLog.write("picked largest \(describe(best)) of \(pool.count)")
            return best
        }
        LayoutLog.write("no-usable-window role=\(role(of: app) ?? "?") windows=\(pool.count)")
        return nil
    }

    /// Electron keeps a blank window list until these are set, and the focused element is often a web view.
    private static func prepare(_ app: AXUIElement) {
        AXUIElementSetMessagingTimeout(app, 2)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue!)
        AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue!)
    }

    private static func windowAncestor(of element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        for _ in 0..<16 {
            guard let node = current else { return nil }
            if role(of: node) == (kAXWindowRole as String) { return node }
            current = copyElement(node, kAXParentAttribute as String)
        }
        return nil
    }

    private static func bestWindow(from list: [AXUIElement]) -> AXUIElement? {
        var seen: [AXUIElement] = []
        for window in list where isResizableWindow(window) {
            if !seen.contains(where: { sameWindow($0, window) }) {
                seen.append(window)
            }
        }
        let standard = seen.filter { subrole(of: $0) == (kAXStandardWindowSubrole as String) }
        let pool = standard.isEmpty ? seen : standard
        return pool.max { area($0) < area($1) }
    }

    private static func isResizableWindow(_ window: AXUIElement) -> Bool {
        if role(of: window) != (kAXWindowRole as String) { return false }
        if boolAttribute(window, kAXMinimizedAttribute as String) { return false }
        let sub = subrole(of: window)
        if sub == "AXUnknown" || sub == (kAXSystemDialogSubrole as String) { return false }
        guard let raw = rawFrame(of: window) else { return false }
        return raw.width > 80 && raw.height > 60
    }

    private static func sameWindow(_ a: AXUIElement, _ b: AXUIElement) -> Bool {
        var left: pid_t = 0
        var right: pid_t = 0
        AXUIElementGetPid(a, &left)
        AXUIElementGetPid(b, &right)
        guard left == right, let af = rawFrame(of: a), let bf = rawFrame(of: b) else { return false }
        return framesClose(af, bf) && stringAttribute(a, kAXTitleAttribute as String) == stringAttribute(b, kAXTitleAttribute as String)
    }

    private static func area(_ window: AXUIElement) -> CGFloat {
        guard let raw = rawFrame(of: window) else { return 0 }
        return raw.width * raw.height
    }

    // MARK: - Attributes

    private static func rawFrame(of window: AXUIElement) -> CGRect? {
        guard let positionValue = copyValue(window, kAXPositionAttribute as String),
              let sizeValue = copyValue(window, kAXSizeAttribute as String)
        else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &point),
              AXValueGetValue(sizeValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: point, size: size)
    }

    private static var settleID = 0

    /// After Bottom Half the window sits on the lower edge. Growing the height in the same step as the move is ignored, and moving again afterwards cancels the size. Park it at the top, then change size only.
    private static func commit(_ target: CGRect, on window: AXUIElement, anchorBottom: Bool) -> Bool {
        settleID += 1
        let id = settleID
        let current = rawFrame(of: window)
        let growing = current.map {
            $0.width + 8 < target.width || $0.height + 8 < target.height
        } ?? true

        if growing {
            if let current, !placed(current, target) {
                _ = setPosition(target.origin, on: window)
            }
            grow(target, on: window, id: id, attempt: 0)
            return true
        }

        // Shrink first. Moving to the bottom while the window is still full height is rejected, so the first press only nudges it.
        shrink(target, on: window, id: id, attempt: 0, anchorBottom: anchorBottom)
        return true
    }

    private static func shrink(
        _ target: CGRect,
        on window: AXUIElement,
        id: Int,
        attempt: Int,
        anchorBottom: Bool
    ) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 70_000_000)
            guard id == settleID else { return }
            guard let actual = rawFrame(of: window) else { return }
            let sizeClose = abs(actual.width - target.width) < 16 && abs(actual.height - target.height) < 30
            if !sizeClose, attempt < 5 {
                _ = setSize(target.size, on: window)
                let after = rawFrame(of: window) ?? actual
                LayoutLog.write("shrink-size \(attempt) actual=\(rectString(after))")
                shrink(target, on: window, id: id, attempt: attempt + 1, anchorBottom: anchorBottom)
                return
            }
            let origin = anchorBottom
                ? CGPoint(x: target.minX, y: target.maxY - actual.height)
                : target.origin
            if abs(actual.minX - origin.x) > 4 || abs(actual.minY - origin.y) > 4, attempt < 9 {
                _ = setPosition(origin, on: window)
                let after = rawFrame(of: window) ?? actual
                LayoutLog.write("shrink-move \(attempt) actual=\(rectString(after))")
                shrink(target, on: window, id: id, attempt: attempt + 1, anchorBottom: anchorBottom)
            }
        }
    }

    private static func grow(_ target: CGRect, on window: AXUIElement, id: Int, attempt: Int) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard id == settleID else { return }
            guard let actual = rawFrame(of: window) else { return }

            if !placed(actual, target), attempt < 4 {
                _ = setPosition(target.origin, on: window)
                LayoutLog.write("place \(attempt) actual=\(rectString(actual))")
                grow(target, on: window, id: id, attempt: attempt + 1)
                return
            }

            let sizeOK = setSize(target.size, on: window)
            let after = rawFrame(of: window) ?? actual
            LayoutLog.write("grow \(attempt) sizeOK=\(sizeOK) actual=\(rectString(after))")
            if arrived(after, target) {
                if !placed(after, target) {
                    _ = setPosition(target.origin, on: window)
                }
                return
            }
            if attempt >= 8 { return }
            grow(target, on: window, id: id, attempt: attempt + 1)
        }
    }

    private static func placed(_ actual: CGRect, _ target: CGRect) -> Bool {
        abs(actual.minX - target.minX) < 6 && abs(actual.minY - target.minY) < 6
    }

    /// A window that will not take the last few points of height still counts as maximized.
    private static func arrived(_ actual: CGRect, _ target: CGRect) -> Bool {
        abs(actual.width - target.width) < 8 && abs(actual.height - target.height) < 20
    }

    private static func setSize(_ size: CGSize, on window: AXUIElement) -> Bool {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value) == .success
    }

    private static func setPosition(_ position: CGPoint, on window: AXUIElement) -> Bool {
        var position = position
        guard let value = AXValueCreate(.cgPoint, &position) else { return false }
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success
    }

    private static func exitFullScreenIfNeeded(_ window: AXUIElement) {
        guard boolAttribute(window, "AXFullScreen") else { return }
        AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, kCFBooleanFalse!)
    }

    private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copyAttribute(element, attribute) else { return nil }
        return axElement(from: value)
    }

    private static func copyElements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        guard let value = copyAttribute(element, attribute) else { return [] }
        return axElements(from: value)
    }

    private static func copyValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        guard let value = copyAttribute(element, attribute) else { return nil }
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

    private static func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        if error == .apiDisabled {
            accessDenied = true
            return nil
        }
        guard error == .success else { return nil }
        return value
    }

    private static func axElement(from value: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func axElements(from value: CFTypeRef) -> [AXUIElement] {
        guard CFGetTypeID(value) == CFArrayGetTypeID() else {
            return axElement(from: value).map { [$0] } ?? []
        }
        let array = value as! CFArray
        var result: [AXUIElement] = []
        for index in 0..<CFArrayGetCount(array) {
            guard let pointer = CFArrayGetValueAtIndex(array, index) else { continue }
            let item = Unmanaged<CFTypeRef>.fromOpaque(pointer).takeUnretainedValue()
            if let element = axElement(from: item) {
                result.append(element)
            }
        }
        return result
    }

    private static func role(of element: AXUIElement) -> String? {
        stringAttribute(element, kAXRoleAttribute as String)
    }

    private static func subrole(of element: AXUIElement) -> String? {
        stringAttribute(element, kAXSubroleAttribute as String)
    }

    private static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        copyAttribute(element, attribute) as? String
    }

    private static func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
        (copyAttribute(element, attribute) as? NSNumber)?.boolValue ?? false
    }

    private static func describe(_ window: AXUIElement) -> String {
        let title = stringAttribute(window, kAXTitleAttribute as String) ?? ""
        let raw = rawFrame(of: window).map(rectString) ?? "?"
        return "subrole=\(subrole(of: window) ?? "-") title=\(title) ax=\(raw)"
    }

    // MARK: - Coordinates

    private static var flipHeight: CGFloat {
        let primary = NSScreen.screens.first { abs($0.frame.origin.x) < 0.5 && abs($0.frame.origin.y) < 0.5 }
        return (primary ?? NSScreen.main)?.frame.maxY ?? 0
    }

    private static func cocoaFrame(fromAX raw: CGRect) -> CGRect {
        var frame = raw
        frame.origin.y = flipHeight - raw.origin.y - raw.height
        return frame
    }

    private static func axFrame(fromCocoa frame: CGRect) -> CGRect {
        var raw = frame
        raw.origin.y = flipHeight - frame.origin.y - frame.height
        return raw
    }

    private static func framesClose(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 8
            && abs(a.minY - b.minY) < 8
            && abs(a.width - b.width) < 8
            && abs(a.height - b.height) < 8
    }

    private static func intersectionArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let hit = a.intersection(b)
        if hit.isNull || hit.isEmpty { return 0 }
        return hit.width * hit.height
    }

    private static func rectString(_ rect: CGRect) -> String {
        String(format: "(%.0f,%.0f %.0fx%.0f)", rect.origin.x, rect.origin.y, rect.width, rect.height)
    }
}
