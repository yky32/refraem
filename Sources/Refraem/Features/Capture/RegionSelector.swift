import AppKit

@MainActor
enum RegionSelector {
    /// Presents a fullscreen dim overlay; returns rect in screen coordinates (bottom-left origin).
    /// Esc, right-click, or a tiny drag always cancels and tears the overlay down.
    static func pickRegion() async throws -> CGRect {
        if let active = RegionSession.active {
            active.forceCancel()
        }
        return try await withCheckedThrowingContinuation { continuation in
            let session = RegionSession(continuation: continuation)
            RegionSession.active = session
            session.begin()
        }
    }
}

@MainActor
private final class RegionSession: NSObject {
    static var active: RegionSession?

    private var continuation: CheckedContinuation<CGRect, Error>?
    private var windows: [RegionOverlayWindow] = []
    private var currentRect: CGRect = .zero
    private var monitors: [Any] = []
    private var finished = false

    init(continuation: CheckedContinuation<CGRect, Error>) {
        self.continuation = continuation
    }

    func begin() {
        for screen in NSScreen.screens {
            let window = RegionOverlayWindow(screen: screen, session: self)
            windows.append(window)
            window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
        if let first = windows.first {
            first.makeKeyAndOrderFront(nil)
            first.contentView?.window?.makeFirstResponder(first.contentView)
        }

        // Local: Esc while Refraem is active.
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if self?.handleKey(event) == true { return nil }
            return event
        }) {
            monitors.append(local)
        }
        // Global: Esc even if focus slipped away under the overlay.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            _ = self?.handleKey(event)
        }) {
            monitors.append(global)
        }
    }

    @discardableResult
    private func handleKey(_ event: NSEvent) -> Bool {
        // Esc or ⌘.
        if event.keyCode == 53 || (event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == ".") {
            finish(cancelled: true)
            return true
        }
        if event.keyCode == 36 || event.keyCode == 76 {
            finish(cancelled: false)
            return true
        }
        return false
    }

    func update(start: NSPoint, current: NSPoint) {
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(start.x - current.x)
        let h = abs(start.y - current.y)
        currentRect = CGRect(x: x, y: y, width: w, height: h)
        windows.forEach { $0.selectionRect = currentRect }
    }

    func finish(cancelled: Bool) {
        guard !finished else { return }
        finished = true
        guard let continuation else {
            teardown()
            return
        }
        self.continuation = nil
        let rect = currentRect
        teardown()
        if cancelled || rect.width < 4 || rect.height < 4 {
            continuation.resume(throwing: CaptureError.cancelled)
        } else {
            continuation.resume(returning: rect)
        }
    }

    func forceCancel() {
        finish(cancelled: true)
    }

    private func teardown() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows.removeAll()
        if RegionSession.active === self {
            RegionSession.active = nil
        }
    }
}

@MainActor
private final class RegionOverlayWindow: NSWindow {
    private weak var session: RegionSession?
    var selectionRect: CGRect = .zero {
        didSet { contentView?.needsDisplay = true }
    }

    init(screen: NSScreen, session: RegionSession) {
        self.session = session
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        setFrame(screen.frame, display: true)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false
        contentView = RegionOverlayView(session: session, windowRef: self)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class RegionOverlayView: NSView {
    private weak var session: RegionSession?
    private weak var windowRef: RegionOverlayWindow?
    private var dragStart: NSPoint?

    init(session: RegionSession, windowRef: RegionOverlayWindow) {
        self.session = session
        self.windowRef = windowRef
        super.init(frame: .zero)
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        let dim = NSBezierPath(rect: bounds)
        if let rect = windowRef?.selectionRect, rect.width > 2, rect.height > 2 {
            let local = convertScreenRectToLocal(rect)
            dim.append(NSBezierPath(rect: local))
            dim.windingRule = .evenOdd
            NSColor.black.withAlphaComponent(0.45).setFill()
            dim.fill()

            NSColor.white.setStroke()
            let path = NSBezierPath(rect: local)
            path.lineWidth = 2
            path.stroke()
        } else {
            NSColor.black.withAlphaComponent(0.45).setFill()
            dim.fill()
        }

        let hint = "Drag to select · Esc to cancel"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92),
        ]
        let size = hint.size(withAttributes: attrs)
        let point = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: bounds.height - size.height - 48
        )
        let pad = NSRect(
            x: point.x - 14,
            y: point.y - 8,
            width: size.width + 28,
            height: size.height + 16
        )
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: pad, xRadius: 10, yRadius: 10).fill()
        hint.draw(at: point, withAttributes: attrs)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 || (event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == ".") {
            session?.finish(cancelled: true)
            return
        }
        if event.keyCode == 36 || event.keyCode == 76 {
            session?.finish(cancelled: false)
            return
        }
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        if event.modifierFlags.contains(.control) {
            session?.finish(cancelled: true)
            return
        }
        dragStart = NSEvent.mouseLocation
    }

    override func rightMouseDown(with event: NSEvent) {
        session?.finish(cancelled: true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        session?.update(start: start, current: NSEvent.mouseLocation)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        session?.update(start: start, current: NSEvent.mouseLocation)
        dragStart = nil
        // Finish on release so the user is never stuck waiting for Return / Esc.
        session?.finish(cancelled: false)
    }

    override func cancelOperation(_ sender: Any?) {
        session?.finish(cancelled: true)
    }

    private func convertScreenRectToLocal(_ screenRect: CGRect) -> NSRect {
        guard let window = windowRef else { return .zero }
        let origin = window.convertPoint(fromScreen: NSPoint(x: screenRect.minX, y: screenRect.minY))
        let end = window.convertPoint(fromScreen: NSPoint(x: screenRect.maxX, y: screenRect.maxY))
        return NSRect(
            x: min(origin.x, end.x),
            y: min(origin.y, end.y),
            width: abs(end.x - origin.x),
            height: abs(end.y - origin.y)
        )
    }
}
