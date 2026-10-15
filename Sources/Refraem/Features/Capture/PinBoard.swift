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

enum MarkupBurn {
    /// Strokes are in top-left image pixel space. Ink is black (brand palette).
    static func burn(strokes: [[CGPoint]], into image: CGImage) -> CGImage {
        let drawn = strokes.filter { $0.count > 1 }
        guard !drawn.isEmpty else { return image }
        let width = image.width
        let height = image.height
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.setLineWidth(max(2, CGFloat(width) / 280))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for stroke in drawn {
            guard let first = stroke.first else { continue }
            ctx.beginPath()
            ctx.move(to: first)
            for point in stroke.dropFirst() {
                ctx.addLine(to: point)
            }
            ctx.strokePath()
        }
        return ctx.makeImage() ?? image
    }
}
