import Foundation

enum UtilityAction: Hashable {
    case window(WindowSnap)
    case capture(CaptureMode)
    case record(RecordMode)
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
    case maximize
    case almostMaximize
    case maximizeHeight
    case larger
    case smaller
    case center
    case restore
    case nextDisplay
    case previousDisplay

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
        case .maximize: "Maximize"
        case .almostMaximize: "Almost Maximize"
        case .maximizeHeight: "Maximize Height"
        case .larger: "Larger"
        case .smaller: "Smaller"
        case .center: "Center"
        case .restore: "Restore"
        case .nextDisplay: "Next Display"
        case .previousDisplay: "Previous Display"
        }
    }

    var symbolName: String {
        switch self {
        case .leftHalf: "rectangle.lefthalf.filled"
        case .rightHalf: "rectangle.righthalf.filled"
        case .centerHalf: "rectangle.split.2x1"
        case .topHalf: "rectangle.tophalf.filled"
        case .bottomHalf: "rectangle.bottomhalf.filled"
        case .topLeft: "rectangle.inset.filled"
        case .topRight: "rectangle.inset.filled"
        case .bottomLeft: "rectangle.inset.filled"
        case .bottomRight: "rectangle.inset.filled"
        case .firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds:
            "rectangle.split.3x1"
        case .maximize: "arrow.up.left.and.arrow.down.right"
        case .almostMaximize: "rectangle.inset.filled"
        case .maximizeHeight: "arrow.up.and.down"
        case .larger: "plus.rectangle"
        case .smaller: "minus.rectangle"
        case .center: "square.dashed"
        case .restore: "arrow.uturn.backward"
        case .nextDisplay: "chevron.right.2"
        case .previousDisplay: "chevron.left.2"
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

enum RecordMode: String, Hashable {
    case screen
    case area
    case stop

    var menuTitle: String {
        switch self {
        case .screen: "Record Screen"
        case .area: "Record Area"
        case .stop: "Stop Recording"
        }
    }
}
