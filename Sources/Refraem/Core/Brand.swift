import Foundation

enum Brand {
    static let name = "Refraem"

    /// Marketing pronunciation (spelling differs for trademark/domain).
    static let spokenName = "Reframe"
    static let pronunciation = "ree-FRAME"

    static var spokenHint: String {
        "Pronounced \(spokenName) (\(pronunciation))."
    }

    static let tagline = "Window layout and screen capture for Mac."
    static let technologyNote = "Native Swift · macOS menu bar app"

    static let alternateSpelling = "Refraime"
    static let bundleIdentifier = "app.yky.refraem"
}
