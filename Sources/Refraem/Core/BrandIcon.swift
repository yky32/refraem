import AppKit

enum BrandIcon {
    /// Menu bar status item. Same mark as the brand logo, scaled to the full width of the status slot.
    @MainActor
    static func menuBarImage() -> NSImage? {
        let slot = NSStatusBar.system.thickness
        let image = NSImage(size: NSSize(width: slot, height: slot), flipped: true) { dst in
            // Tight bounds of the two frames plus stroke, so the mark meets the left and right edges.
            let art = CGRect(x: 4.55, y: 5.85, width: 15.1, height: 12.3)
            let scale = dst.width / art.width
            let origin = CGPoint(
                x: -art.minX * scale,
                y: (dst.height - art.height * scale) / 2 - art.minY * scale
            )
            let transform = NSAffineTransform()
            transform.translateX(by: origin.x, yBy: origin.y)
            transform.scale(by: scale)
            transform.concat()

            func stroke(_ path: NSBezierPath, width: CGFloat, alpha: CGFloat) {
                path.lineWidth = width
                path.lineJoinStyle = .round
                NSColor.black.withAlphaComponent(alpha).setStroke()
                path.stroke()
            }

            let back = NSBezierPath(
                roundedRect: NSRect(x: 5.25, y: 6.75, width: 9, height: 10.5),
                xRadius: 2.5,
                yRadius: 2.5
            )
            stroke(back, width: 1.15, alpha: 0.4)

            let front = NSBezierPath(
                roundedRect: NSRect(x: 9.75, y: 6.75, width: 9, height: 10.5),
                xRadius: 2.5,
                yRadius: 2.5
            )
            stroke(front, width: 1.6, alpha: 1)

            let lens = NSBezierPath(
                ovalIn: NSRect(x: 14.25 - 2.08, y: 12 - 2.08, width: 4.16, height: 4.16)
            )
            stroke(lens, width: 1.2, alpha: 1)
            return true
        }
        image.isTemplate = true
        return image
    }

    @MainActor
    private static func fallbackMenuBarImage() -> NSImage? {
        let image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: Brand.name)
        image?.isTemplate = true
        return image
    }

    /// Color mark for Settings / About.
    @MainActor
    static func colorMarkImage() -> NSImage? {
        if let url = Bundle.module.url(forResource: "refraem-mark-color", withExtension: "svg", subdirectory: "Brand"),
           let image = NSImage(contentsOf: url)
        {
            image.size = NSSize(width: 48, height: 48)
            return image
        }
        if let url = Bundle.module.url(forResource: "refraem-app-icon", withExtension: "jpg", subdirectory: "Brand"),
           let image = NSImage(contentsOf: url)
        {
            image.size = NSSize(width: 48, height: 48)
            return image
        }
        return nil
    }
}
