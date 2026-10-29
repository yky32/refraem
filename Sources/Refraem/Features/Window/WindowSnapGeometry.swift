import CoreGraphics

enum WindowSnapGeometry {
    /// `current` is the window’s frame. `visible` is the target screen’s usable area (menu bar and Dock excluded).
    static func rect(for snap: WindowSnap, current: CGRect, in visible: CGRect) -> CGRect? {
        let w = visible.width
        let h = visible.height
        let x = visible.minX
        let y = visible.minY

        switch snap {
        case .leftHalf:
            return CGRect(x: x, y: y, width: w / 2, height: h)
        case .rightHalf:
            return CGRect(x: x + w / 2, y: y, width: w / 2, height: h)
        case .centerHalf:
            return CGRect(x: x + w / 4, y: y, width: w / 2, height: h)
        case .topHalf:
            return CGRect(x: x, y: y + h / 2, width: w, height: h / 2)
        case .bottomHalf:
            return CGRect(x: x, y: y, width: w, height: h / 2)
        case .topLeft:
            return CGRect(x: x, y: y + h / 2, width: w / 2, height: h / 2)
        case .topRight:
            return CGRect(x: x + w / 2, y: y + h / 2, width: w / 2, height: h / 2)
        case .bottomLeft:
            return CGRect(x: x, y: y, width: w / 2, height: h / 2)
        case .bottomRight:
            return CGRect(x: x + w / 2, y: y, width: w / 2, height: h / 2)
        case .firstThird:
            return CGRect(x: x, y: y, width: w / 3, height: h)
        case .centerThird:
            return CGRect(x: x + w / 3, y: y, width: w / 3, height: h)
        case .lastThird:
            return CGRect(x: x + 2 * w / 3, y: y, width: w / 3, height: h)
        case .firstTwoThirds:
            return CGRect(x: x, y: y, width: 2 * w / 3, height: h)
        case .lastTwoThirds:
            return CGRect(x: x + w / 3, y: y, width: 2 * w / 3, height: h)
        case .maximize:
            return visible
        case .almostMaximize:
            return visible.insetBy(dx: 16, dy: 16)
        case .maximizeHeight:
            return fit(CGRect(x: current.minX, y: y, width: current.width, height: h), in: visible)
        case .larger:
            return resized(current, in: visible, delta: 1)
        case .smaller:
            return resized(current, in: visible, delta: -1)
        case .center:
            return centered(current, in: visible)
        case .restore, .nextDisplay, .previousDisplay:
            return nil
        }
    }

    private static func resized(_ current: CGRect, in visible: CGRect, delta: CGFloat) -> CGRect {
        let stepW = max(32, visible.width * 0.08)
        let stepH = max(32, visible.height * 0.08)
        let minW: CGFloat = 280
        let minH: CGFloat = 180
        let width = min(visible.width, max(minW, current.width + delta * stepW))
        let height = min(visible.height, max(minH, current.height + delta * stepH))
        let proposed = CGRect(
            x: current.midX - width / 2,
            y: current.midY - height / 2,
            width: width,
            height: height
        )
        return fit(proposed, in: visible)
    }

    private static func centered(_ current: CGRect, in visible: CGRect) -> CGRect {
        let width = min(current.width, visible.width)
        let height = min(current.height, visible.height)
        return CGRect(
            x: visible.midX - width / 2,
            y: visible.midY - height / 2,
            width: width,
            height: height
        )
    }

    static func placed(_ window: CGRect, from: CGRect, onto destination: CGRect) -> CGRect {
        let width = min(window.width, destination.width)
        let height = min(window.height, destination.height)
        let relX = from.width > 0 ? (window.midX - from.minX) / from.width : 0.5
        let relY = from.height > 0 ? (window.midY - from.minY) / from.height : 0.5
        let proposed = CGRect(
            x: destination.minX + relX * destination.width - width / 2,
            y: destination.minY + relY * destination.height - height / 2,
            width: width,
            height: height
        )
        return fit(proposed, in: destination)
    }

    private static func fit(_ frame: CGRect, in visible: CGRect) -> CGRect {
        var result = frame
        result.size.width = min(result.width, visible.width)
        result.size.height = min(result.height, visible.height)
        if result.minX < visible.minX { result.origin.x = visible.minX }
        if result.minY < visible.minY { result.origin.y = visible.minY }
        if result.maxX > visible.maxX { result.origin.x = visible.maxX - result.width }
        if result.maxY > visible.maxY { result.origin.y = visible.maxY - result.height }
        return result
    }
}
