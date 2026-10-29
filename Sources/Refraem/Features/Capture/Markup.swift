import AppKit
import CoreImage

struct MarkupColor: Equatable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    var nsColor: NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    static func from(_ color: NSColor) -> MarkupColor {
        let converted = color.usingColorSpace(.sRGB) ?? color
        return MarkupColor(
            red: converted.redComponent,
            green: converted.greenComponent,
            blue: converted.blueComponent,
            alpha: converted.alphaComponent
        )
    }

    var hex: String {
        String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

enum MarkupItem: Equatable {
    case pen([CGPoint], MarkupColor, CGFloat)
    case highlight([CGPoint], MarkupColor, CGFloat)
    case line(CGPoint, CGPoint, MarkupColor, CGFloat)
    case arrow(CGPoint, CGPoint, MarkupColor, CGFloat)
    case rectangle(CGPoint, CGPoint, MarkupColor, CGFloat)
    case oval(CGPoint, CGPoint, MarkupColor, CGFloat)
    case text(String, CGPoint, MarkupColor, CGFloat)
    case step(Int, CGPoint, MarkupColor)
    case blur(CGRect)
    case pixelate(CGRect)
}

enum BackdropStyle: Int, CaseIterable, Equatable {
    case off, light, dark, gradient

    var title: String {
        switch self {
        case .off: "Off"
        case .light: "Light"
        case .dark: "Dark"
        case .gradient: "Gradient"
        }
    }

    var next: BackdropStyle {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    func padding(for image: CGImage) -> CGFloat {
        guard self != .off else { return 0 }
        return max(72, min(CGFloat(image.width), CGFloat(image.height)) * 0.07)
    }

    func radius(for image: CGImage) -> CGFloat {
        guard self != .off else { return 0 }
        return max(18, min(CGFloat(image.width), CGFloat(image.height)) * 0.02)
    }
}

enum MarkupRenderer {
    static func burn(_ items: [MarkupItem], into image: CGImage) -> CGImage {
        guard !items.isEmpty else { return image }
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

        for item in items {
            switch item {
            case .blur(let rect):
                if let current = ctx.makeImage() {
                    drawEffect(current, rect: rect, pixelate: false, into: ctx)
                }
            case .pixelate(let rect):
                if let current = ctx.makeImage() {
                    drawEffect(current, rect: rect, pixelate: true, into: ctx)
                }
            case .pen(let points, let color, let width):
                stroke(points, color: color, width: width, alpha: 1, in: ctx)
            case .highlight(let points, let color, let width):
                stroke(points, color: color, width: width, alpha: 0.45, in: ctx)
            case .line(let a, let b, let color, let width):
                stroke([a, b], color: color, width: width, alpha: 1, in: ctx)
            case .arrow(let a, let b, let color, let width):
                stroke([a, b], color: color, width: width, alpha: 1, in: ctx)
                drawArrowHead(from: a, to: b, color: color, length: max(14, width * 4), in: ctx)
            case .rectangle(let a, let b, let color, let width):
                ctx.setStrokeColor(color.nsColor.cgColor)
                ctx.setLineWidth(width)
                ctx.stroke(rect(a, b))
            case .oval(let a, let b, let color, let width):
                ctx.setStrokeColor(color.nsColor.cgColor)
                ctx.setLineWidth(width)
                ctx.strokeEllipse(in: rect(a, b))
            case .text(let string, let origin, let color, let size):
                drawText(string, at: origin, color: color, size: size, in: ctx)
            case .step(let number, let center, let color):
                drawStep(number, at: center, color: color, in: ctx)
            }
        }
        return ctx.makeImage() ?? image
    }

    /// Wraps a screenshot in padding, rounded corners, and a shadow. Off returns the image unchanged.
    static func present(_ image: CGImage, backdrop: BackdropStyle) -> CGImage {
        guard backdrop != .off else { return image }
        let pad = backdrop.padding(for: image)
        let radius = backdrop.radius(for: image)
        let width = image.width + Int(pad * 2)
        let height = image.height + Int(pad * 2)
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        let colors = backdropColors(backdrop)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: CGFloat(height)),
                options: []
            )
        }

        let photo = CGRect(x: pad, y: pad, width: CGFloat(image.width), height: CGFloat(image.height))
        let clip = CGPath(roundedRect: photo, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -(pad * 0.12)),
            blur: pad * 0.35,
            color: NSColor.black.withAlphaComponent(0.28).cgColor
        )
        ctx.addPath(clip)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(clip)
        ctx.clip()
        ctx.draw(image, in: photo)
        ctx.restoreGState()
        return ctx.makeImage() ?? image
    }

    static func sample(_ image: CGImage, at point: CGPoint) -> MarkupColor? {
        let x = Int(point.x.rounded(.down))
        let y = Int(point.y.rounded(.down))
        guard x >= 0, y >= 0, x < image.width, y < image.height else { return nil }
        guard let ctx = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let ptr = ctx.data else { return nil }
        let pixel = ptr.bindMemory(to: UInt8.self, capacity: 4)
        let flippedY = image.height - 1 - y
        ctx.draw(image, in: CGRect(x: -CGFloat(x), y: -CGFloat(flippedY), width: CGFloat(image.width), height: CGFloat(image.height)))
        return MarkupColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        )
    }

    private static func backdropColors(_ style: BackdropStyle) -> [CGColor] {
        switch style {
        case .off, .light:
            return [
                NSColor(calibratedWhite: 0.97, alpha: 1).cgColor,
                NSColor(calibratedWhite: 0.88, alpha: 1).cgColor,
            ]
        case .dark:
            return [
                NSColor(calibratedWhite: 0.24, alpha: 1).cgColor,
                NSColor(calibratedWhite: 0.10, alpha: 1).cgColor,
            ]
        case .gradient:
            return [
                NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.97, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.78, green: 0.82, blue: 0.88, alpha: 1).cgColor,
            ]
        }
    }

    static func crop(_ image: CGImage, to rect: CGRect) -> CGImage? {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let clipped = rect.integral.intersection(bounds)
        guard clipped.width > 4, clipped.height > 4 else { return nil }
        return image.cropping(to: clipped)
    }

    private static func stroke(_ points: [CGPoint], color: MarkupColor, width: CGFloat, alpha: CGFloat, in ctx: CGContext) {
        guard points.count > 1 else { return }
        ctx.setStrokeColor(color.nsColor.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.beginPath()
        ctx.move(to: points[0])
        for point in points.dropFirst() {
            ctx.addLine(to: point)
        }
        ctx.strokePath()
    }

    private static func drawArrowHead(from: CGPoint, to: CGPoint, color: MarkupColor, length: CGFloat, in ctx: CGContext) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let left = CGPoint(x: to.x + length * cos(angle + .pi * 0.82), y: to.y + length * sin(angle + .pi * 0.82))
        let right = CGPoint(x: to.x + length * cos(angle - .pi * 0.82), y: to.y + length * sin(angle - .pi * 0.82))
        ctx.setFillColor(color.nsColor.cgColor)
        ctx.beginPath()
        ctx.move(to: to)
        ctx.addLine(to: left)
        ctx.addLine(to: right)
        ctx.closePath()
        ctx.fillPath()
    }

    private static func drawText(_ string: String, at origin: CGPoint, color: MarkupColor, size: CGFloat, in ctx: CGContext) {
        let font = NSFont.systemFont(ofSize: size, weight: .semibold)
        guard let (textImage, textSize) = rasterText(string, font: font, color: color.nsColor) else { return }
        drawUpright(textImage, in: CGRect(x: origin.x, y: origin.y, width: textSize.width, height: textSize.height), ctx: ctx)
    }

    private static func drawStep(_ number: Int, at center: CGPoint, color: MarkupColor, in ctx: CGContext) {
        let radius: CGFloat = 18
        ctx.setFillColor(color.nsColor.cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        let font = NSFont.systemFont(ofSize: 15, weight: .bold)
        guard let (textImage, textSize) = rasterText("\(number)", font: font, color: .white) else { return }
        drawUpright(
            textImage,
            in: CGRect(
                x: center.x - textSize.width / 2,
                y: center.y - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            ),
            ctx: ctx
        )
    }

    /// The capture context is y-down. A normal CGImage would paint upside down, so flip it back.
    private static func drawUpright(_ image: CGImage, in rect: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: rect.midX, y: rect.midY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: -rect.midX, y: -rect.midY)
        ctx.draw(image, in: rect)
        ctx.restoreGState()
    }

    private static func rasterText(_ string: String, font: NSFont, color: NSColor) -> (CGImage, CGSize)? {
        let text = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        let size = text.size()
        let width = max(1, Int(ceil(size.width)) + 2)
        let height = max(1, Int(ceil(size.height)) + 2)
        guard let textCtx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: textCtx, flipped: false)
        text.draw(in: CGRect(x: 1, y: 1, width: size.width, height: size.height))
        NSGraphicsContext.restoreGraphicsState()
        guard let image = textCtx.makeImage() else { return nil }
        return (image, CGSize(width: width, height: height))
    }

    private static func drawEffect(_ image: CGImage, rect: CGRect, pixelate: Bool, into ctx: CGContext) {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let area = rect.standardized.integral.intersection(bounds)
        guard area.width > 2, area.height > 2, let tile = image.cropping(to: area) else { return }
        let processed = pixelate ? pixelated(tile) : blurred(tile)
        ctx.draw(processed, in: area)
    }

    private static func blurred(_ image: CGImage) -> CGImage {
        let input = CIImage(cgImage: image)
        let output = input
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 16])
            .cropped(to: input.extent)
        return CIContext(options: nil).createCGImage(output, from: input.extent) ?? image
    }

    private static func pixelated(_ image: CGImage) -> CGImage {
        let smallW = max(1, image.width / 14)
        let smallH = max(1, image.height / 14)
        guard
            let small = CGContext(
                data: nil, width: smallW, height: smallH, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let big = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return image }
        small.interpolationQuality = .none
        small.draw(image, in: CGRect(x: 0, y: 0, width: smallW, height: smallH))
        guard let tiny = small.makeImage() else { return image }
        big.interpolationQuality = .none
        big.draw(tiny, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return big.makeImage() ?? image
    }

    private static func rect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}
