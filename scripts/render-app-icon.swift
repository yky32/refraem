import AppKit

let size = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("could not create bitmap\n", stderr)
    exit(1)
}
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: CGFloat(size) / 256, y: -CGFloat(size) / 256)

let background = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 256, height: 256), xRadius: 56, yRadius: 56)
NSColor.black.setFill()
background.fill()

let art = CGRect(x: 2.7, y: 4.44, width: 18.6, height: 15.12)
let box: CGFloat = 204.8
let markScale = min(box / art.width, box / art.height)
let drawW = art.width * markScale
let drawH = art.height * markScale
let ox = 25.6 + (box - drawW) / 2
let oy = 25.6 + (box - drawH) / 2
let transform = NSAffineTransform()
transform.translateX(by: ox - art.minX * markScale, yBy: oy - art.minY * markScale)
transform.scale(by: markScale)
transform.concat()

func stroke(_ path: NSBezierPath, width: CGFloat, alpha: CGFloat) {
    path.lineWidth = width
    path.lineJoinStyle = .round
    NSColor.white.withAlphaComponent(alpha).setStroke()
    path.stroke()
}

let back = NSBezierPath(roundedRect: NSRect(x: 5.25, y: 6.75, width: 9, height: 10.5), xRadius: 2.5, yRadius: 2.5)
stroke(back, width: 1.15, alpha: 0.4)
let front = NSBezierPath(roundedRect: NSRect(x: 9.75, y: 6.75, width: 9, height: 10.5), xRadius: 2.5, yRadius: 2.5)
stroke(front, width: 1.6, alpha: 1)
let lens = NSBezierPath(ovalIn: NSRect(x: 14.25 - 2.08, y: 12 - 2.08, width: 4.16, height: 4.16))
stroke(lens, width: 1.2, alpha: 1)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("could not encode png\n", stderr)
    exit(1)
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
try png.write(to: URL(fileURLWithPath: out))
