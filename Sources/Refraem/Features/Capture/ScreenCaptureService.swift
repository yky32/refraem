import AppKit
@preconcurrency import ScreenCaptureKit

enum ScreenCaptureService {
    static func captureMainDisplay() async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let mainID = CGMainDisplayID()
        guard let display = content.displays.first(where: { $0.displayID == mainID }) ?? content.displays.first else {
            throw CaptureError.noDisplay
        }
        return try await capture(display: display, sourceRect: nil)
    }

    static func capture(rectInScreenSpace: CGRect) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let center = CGPoint(x: rectInScreenSpace.midX, y: rectInScreenSpace.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }),
              let display = content.displays.first(where: { $0.displayID == screen.displayID })
        else {
            throw CaptureError.noDisplay
        }

        let local = CGRect(
            x: rectInScreenSpace.origin.x - screen.frame.origin.x,
            y: rectInScreenSpace.origin.y - screen.frame.origin.y,
            width: rectInScreenSpace.width,
            height: rectInScreenSpace.height
        )
        return try await capture(display: display, sourceRect: local)
    }

    private static func capture(display: SCDisplay, sourceRect: CGRect?) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.captureResolution = .best
        config.showsCursor = true
        if let sourceRect, sourceRect.width > 2, sourceRect.height > 2 {
            config.sourceRect = sourceRect
        }
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
