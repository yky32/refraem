import AppKit
import UniformTypeIdentifiers

enum CaptureOutput {
    static func saveDirectory() -> URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let dir = pictures.appendingPathComponent("Refraem", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func copyToClipboard(_ image: CGImage) {
        let size = NSSize(width: image.width, height: image.height)
        let nsImage = NSImage(cgImage: image, size: size)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([nsImage])
    }

    @discardableResult
    static func savePNG(_ image: CGImage) throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let name = "Refraem-\(formatter.string(from: Date())).png"
        let url = saveDirectory().appendingPathComponent(name)
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw CaptureError.encodeFailed
        }
        try data.write(to: url)
        return url
    }
}

enum CaptureError: Error {
    case noDisplay
    case captureFailed
    case encodeFailed
    case cancelled
}
