import AppKit

@MainActor
final class CaptureEngine {
    static let shared = CaptureEngine()

    func perform(_ mode: CaptureMode) {
        Task {
            guard await ScreenRecordingAccess.ensure() else { return }
            await run(mode)
        }
    }

    private func run(_ mode: CaptureMode) async {
        do {
            let image: CGImage
            switch mode {
            case .screen:
                image = try await ScreenCaptureService.captureMainDisplay()
            case .area:
                let rect = try await RegionSelector.pickRegion()
                image = try await ScreenCaptureService.capture(rectInScreenSpace: rect)
            case .scrolling:
                let rect = try await RegionSelector.pickRegion()
                image = try await ScrollingCapture.capture(region: rect)
            case .recognizeTextOrQR:
                let rect = try await RegionSelector.pickRegion()
                image = try await ScreenCaptureService.capture(rectInScreenSpace: rect)
                let text = try TextRecognitionService.recognizeText(in: image)
                if text.isEmpty {
                    notify("No text found", "Try selecting a clearer area.")
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    notify("Copied text", "\(text.prefix(120))\(text.count > 120 ? "…" : "")")
                }
                return
            }

            CaptureOutput.copyToClipboard(image)
            let url = try? CaptureOutput.savePNG(image)
            CapturePreviewWindowController.shared.show(image: image, savedURL: url)
        } catch CaptureError.cancelled {
            return
        } catch {
            notify("Capture failed", error.localizedDescription)
        }
    }

    private func notify(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
