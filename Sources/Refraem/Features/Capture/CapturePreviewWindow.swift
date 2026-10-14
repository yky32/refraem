import AppKit

@MainActor
final class CapturePreviewWindowController {
    static let shared = CapturePreviewWindowController()
    private var window: NSWindow?

    func show(image: CGImage, savedURL: URL?) {
        let size = NSSize(width: min(900, CGFloat(image.width)), height: min(600, CGFloat(image.height)))
        let view = CapturePreviewView(image: image, savedURL: savedURL)
        let hosting = NSHostingView(rootView: view)

        if window == nil {
            window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window?.title = "\(Brand.name) Capture"
            window?.minSize = NSSize(width: 320, height: 240)
        }
        window?.contentView = hosting
        window?.setContentSize(size)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

import SwiftUI

private struct CapturePreviewView: View {
    let image: CGImage
    let savedURL: URL?

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                if let savedURL {
                    Text("Saved: \(savedURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Copy") {
                    CaptureOutput.copyToClipboard(image)
                }
                .keyboardShortcut("c", modifiers: .command)
            }
        }
        .padding(16)
    }
}
