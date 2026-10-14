import Foundation

enum UtilityAction: Hashable {
    case window(WindowSnap)
    case capture(CaptureMode)
    case openSettings
    case quit
}

enum WindowSnap: String, Hashable, CaseIterable {
    case leftHalf
    case rightHalf
    case centerHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case firstThird
    case centerThird
    case lastThird
    case firstTwoThirds
    case lastTwoThirds

    var menuTitle: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .centerHalf: "Center Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .firstThird: "First Third"
        case .centerThird: "Center Third"
        case .lastThird: "Last Third"
        case .firstTwoThirds: "First Two Thirds"
        case .lastTwoThirds: "Last Two Thirds"
        }
    }
}

enum CaptureMode: String, Hashable {
    case screen
    case area
    case scrolling
    case recognizeTextOrQR

    var menuTitle: String {
        switch self {
        case .screen: "Capture Screen"
        case .area: "Capture Area"
        case .scrolling: "Scrolling Capture"
        case .recognizeTextOrQR: "Recognize Text/QR"
        }
    }
}
