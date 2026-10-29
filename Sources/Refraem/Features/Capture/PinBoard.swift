import AppKit

@MainActor
final class PinBoard {
    static let shared = PinBoard()
    private var windows: [NSWindow] = []

    func pin(image: CGImage) {
        let maxWidth: CGFloat = 420
        let scale = min(1, maxWidth / CGFloat(image.width))
        let size = NSSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = NSImageView(image: NSImage(cgImage: image, size: size))
        window.setContentSize(size)
        window.center()
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
        windows.removeAll { !$0.isVisible }
    }
}
