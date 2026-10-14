import CoreGraphics

enum WindowSnapGeometry {
    static func rect(for snap: WindowSnap, in visible: CGRect) -> CGRect {
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
        }
    }
}
