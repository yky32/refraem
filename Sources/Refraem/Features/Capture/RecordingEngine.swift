import AppKit
import AVFoundation
import CoreMedia
import CoreVideo
import ScreenCaptureKit

/// Screen-only recording. No microphone — that needs a separate permission decision.
@MainActor
final class RecordingEngine {
    static let shared = RecordingEngine()

    private(set) var isRecording = false
    private var session: RecordSession?

    func toggleScreen() {
        if isRecording {
            stop()
            return
        }
        Task { await start(region: nil) }
    }

    func toggleArea() {
        if isRecording {
            stop()
            return
        }
        Task { await startArea() }
    }

    func stop() {
        guard let session else { return }
        self.session = nil
        isRecording = false
        Task {
            let url = await session.finish()
            if let url {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    private func startArea() async {
        do {
            let rect = try await RegionSelector.pickRegion()
            await start(region: rect)
        } catch CaptureError.cancelled {
            return
        } catch {
            alert("Record failed", error.localizedDescription)
        }
    }

    private func start(region: CGRect?) async {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            alert("Screen Recording access required", "Enable Refraem in System Settings → Privacy & Security → Screen Recording.")
            return
        }
        do {
            let session = try await RecordSession.start(region: region)
            self.session = session
            isRecording = true
        } catch {
            alert("Record failed", error.localizedDescription)
        }
    }

    private func alert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

private final class RecordSession: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let stream: SCStream
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let queue = DispatchQueue(label: "app.yky.refraem.record")
    private let url: URL
    private var started = false
    private var startTime: CMTime = .zero
    private let lock = NSLock()

    private init(stream: SCStream, writer: AVAssetWriter, input: AVAssetWriterInput, url: URL) {
        self.stream = stream
        self.writer = writer
        self.input = input
        self.url = url
    }

    static func start(region: CGRect?) async throws -> RecordSession {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let screen = region.flatMap { rect in
            NSScreen.screens.first { $0.frame.contains(CGPoint(x: rect.midX, y: rect.midY)) }
        } ?? NSScreen.main
        guard let screen,
              let display = content.displays.first(where: { $0.displayID == screen.displayID })
                ?? content.displays.first
        else {
            throw CaptureError.noDisplay
        }

        var pixelWidth = display.width
        var pixelHeight = display.height
        var sourceRect: CGRect?
        if let region {
            let local = CGRect(
                x: region.origin.x - screen.frame.origin.x,
                y: region.origin.y - screen.frame.origin.y,
                width: region.width,
                height: region.height
            )
            sourceRect = local
            let scale = screen.backingScaleFactor
            pixelWidth = max(2, Int(local.width * scale))
            pixelHeight = max(2, Int(local.height * scale))
        }
        pixelWidth -= pixelWidth % 2
        pixelHeight -= pixelHeight % 2

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = pixelWidth
        config.height = pixelHeight
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 6
        if let sourceRect {
            config.sourceRect = sourceRect
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let name = "Refraem-\(formatter.string(from: Date())).mov"
        let url = CaptureOutput.saveDirectory().appendingPathComponent(name)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelWidth,
            AVVideoHeightKey: pixelHeight,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { throw CaptureError.encodeFailed }
        writer.add(input)

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        let session = RecordSession(stream: stream, writer: writer, input: input, url: url)
        try stream.addStreamOutput(session, type: .screen, sampleHandlerQueue: session.queue)
        try await stream.startCapture()
        return session
    }

    func finish() async -> URL? {
        do {
            try await stream.stopCapture()
        } catch {
            // Still try to close the file.
        }
        input.markAsFinished()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writer.finishWriting { cont.resume() }
        }
        return writer.status == .completed ? url : nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        guard let pixel = sampleBuffer.imageBuffer else { return }
        let pts = sampleBuffer.presentationTimeStamp
        lock.lock()
        defer { lock.unlock() }
        if !started {
            guard writer.startWriting() else { return }
            writer.startSession(atSourceTime: pts)
            startTime = pts
            started = true
        }
        guard input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
        _ = pixel
        _ = startTime
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

private extension CMSampleBuffer {
    var isValid: Bool { CMSampleBufferIsValid(self) }
    var imageBuffer: CVPixelBuffer? { CMSampleBufferGetImageBuffer(self) }
}
