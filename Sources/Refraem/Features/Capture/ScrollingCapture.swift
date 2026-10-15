import AppKit
import CoreGraphics

/// Scrolls the page under a region and stitches frames into one tall image.
/// Defaults (no extra UI): scroll down only, ~70% of the region each step, stop when
/// the frame stops changing or after 10 frames.
enum ScrollingCapture {
    static func capture(region: CGRect) async throws -> CGImage {
        var frames: [CGImage] = []
        let first = try await ScreenCaptureService.capture(rectInScreenSpace: region)
        frames.append(first)

        let point = CGPoint(x: region.midX, y: region.midY)
        let step = Int32(max(80, region.height * 0.7))

        for _ in 0..<9 {
            scrollDown(at: point, pixels: step)
            try await Task.sleep(nanoseconds: 320_000_000)
            let next = try await ScreenCaptureService.capture(rectInScreenSpace: region)
            if frames.last.map({ nearlySame($0, next) }) == true {
                break
            }
            frames.append(next)
        }

        guard let stitched = ImageStitcher.vertical(frames) else {
            throw CaptureError.captureFailed
        }
        return stitched
    }

    private static func scrollDown(at point: CGPoint, pixels: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: -pixels,
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.location = point
        event.post(tap: .cghidEventTap)
    }

    private static func nearlySame(_ a: CGImage, _ b: CGImage) -> Bool {
        guard a.width == b.width, a.height == b.height else { return false }
        let score = ImageStitcher.rowDifference(a, y: a.height / 2, b, y: b.height / 2, rows: 6)
        return score < 8
    }
}

enum ImageStitcher {
    static func vertical(_ images: [CGImage]) -> CGImage? {
        guard var result = images.first else { return nil }
        for image in images.dropFirst() {
            let skip = overlapRows(previous: result, next: image)
            guard let next = append(result, image, skippingTop: skip) else { return result }
            result = next
        }
        return result
    }

    /// How many top rows of `next` repeat the bottom of `previous`.
    static func overlapRows(previous: CGImage, next: CGImage) -> Int {
        let height = min(previous.height, next.height)
        guard height > 20 else { return 0 }
        let maxOverlap = Int(Double(height) * 0.8)
        let minOverlap = max(8, Int(Double(height) * 0.12))
        var best = minOverlap
        var bestScore = Int.max
        var overlap = maxOverlap
        while overlap >= minOverlap {
            let yPrev = previous.height - overlap
            let score = rowDifference(previous, y: yPrev, next, y: 0, rows: 6)
            if score < bestScore {
                bestScore = score
                best = overlap
            }
            overlap -= 6
        }
        if bestScore > 40 { return Int(Double(height) * 0.2) }
        return best
    }

    static func rowDifference(_ a: CGImage, y: Int, _ b: CGImage, y yb: Int, rows: Int) -> Int {
        guard let pa = sample(a), let pb = sample(b) else { return 999 }
        let width = min(a.width, b.width)
        var total = 0
        var count = 0
        for row in 0..<rows {
            let ya = y + row
            let y2 = yb + row
            guard ya >= 0, y2 >= 0, ya < a.height, y2 < b.height else { continue }
            var x = 4
            while x < width - 4 {
                let ia = (ya * a.width + x) * 4
                let ib = (y2 * b.width + x) * 4
                if ia + 2 < pa.count, ib + 2 < pb.count {
                    total += abs(Int(pa[ia]) - Int(pb[ib]))
                    total += abs(Int(pa[ia + 1]) - Int(pb[ib + 1]))
                    total += abs(Int(pa[ia + 2]) - Int(pb[ib + 2]))
                    count += 3
                }
                x += max(8, width / 24)
            }
        }
        guard count > 0 else { return 999 }
        return total / count
    }

    private static func append(_ base: CGImage, _ next: CGImage, skippingTop skip: Int) -> CGImage? {
        let add = max(1, next.height - min(skip, next.height - 1))
        let cropY = next.height - add
        guard let cropped = next.cropping(to: CGRect(x: 0, y: cropY, width: next.width, height: add)) else {
            return nil
        }
        let width = max(base.width, cropped.width)
        let height = base.height + cropped.height
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(base, in: CGRect(x: 0, y: 0, width: base.width, height: base.height))
        ctx.draw(cropped, in: CGRect(x: 0, y: base.height, width: cropped.width, height: cropped.height))
        return ctx.makeImage()
    }

    private static func sample(_ image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let count = width * height * 4
        var data = [UInt8](repeating: 0, count: count)
        let ok = data.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return false }
            guard let ctx = CGContext(
                data: base,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return ok ? data : nil
    }
}
