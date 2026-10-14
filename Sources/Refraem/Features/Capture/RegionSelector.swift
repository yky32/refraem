import AppKit

@MainActor
enum RegionSelector {
    /// Presents a fullscreen dim overlay; returns rect in screen coordinates (bottom-left origin).
    static func pickRegion() async throws -> CGRect {
        try await withCheckedThrowingContinuation { continuation in
            let session = RegionSession(continuation: continuation)
            session.begin()
        }
    }
}

@MainActor
private final class RegionSession: NSObject {
    private var continuation: CheckedContinuation<CGRect, Error>?
    private var windows: [RegionOverlayWindow] = []
    private var startPoint: NSPoint?
    private var currentRect: CGRect = .zero
    private var monitors: [Any] = []

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

        monitors.append(NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Esc
                self.finish(cancelled: true)
                return nil
            }
            if event.keyCode == 36 || event.keyCode == 76 { // Return / keypad enter
                self.finish(cancelled: false)
                return nil
            }
            return event
        } as Any)
    }

    func update(start: NSPoint, current: NSPoint) {
        startPoint = start
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(start.x - current.x)
        let h = abs(start.y - current.y)
        currentRect = CGRect(x: x, y: y, width: w, height: h)
        windows.forEach { $0.selectionRect = currentRect }
    }

    func finish(cancelled: Bool) {
        guard let continuation else { return }
        self.continuation = nil
        teardown()
        if cancelled || currentRect.width < 4 || currentRect.height < 4 {
            continuation.resume(throwing: CaptureError.cancelled)
        } else {
            continuation.resume(returning: currentRect)
        }
    }

    private func teardown() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        windows.forEach { $0.close() }
        windows.removeAll()
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
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = RegionOverlayView(session: session, windowRef: self)
    }
}

@MainActor
private final class RegionOverlayView: NSView {
    private weak var session: RegionSession?
    private weak var windowRef: RegionOverlayWindow?
    private var dragStart: NSPoint?

    init(session: RegionSession, windowRef: RegionOverlayWindow) {
        self.session = session
        self.windowRef = windowRef
        super.init(frame: windowRef.frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        dirtyRect.fill()

        guard let rect = windowRef?.selectionRect, rect.width > 0, rect.height > 0 else { return }
        let local = convertScreenRectToLocal(rect)
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: local)
        path.lineWidth = 2
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        session?.update(start: start, current: NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart else { return }
        session?.update(start: start, current: NSEvent.mouseLocation)
        dragStart = nil
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
