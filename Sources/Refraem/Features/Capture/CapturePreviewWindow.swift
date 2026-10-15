import AppKit
import SwiftUI

@MainActor
final class CapturePreviewWindowController {
    static let shared = CapturePreviewWindowController()
    private var window: NSWindow?

    func show(image: CGImage, savedURL: URL?) {
        let size = NSSize(width: min(900, CGFloat(image.width) + 32), height: min(640, CGFloat(image.height) + 80))
        let hosting = NSHostingView(rootView: CapturePreviewView(image: image, savedURL: savedURL))

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

private struct CapturePreviewView: View {
    let image: CGImage
    let savedURL: URL?

    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let fitted = aspectFit(imageSize: CGSize(width: image.width, height: image.height), in: geo.size)
                ZStack {
                    Image(nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                    Canvas { context, _ in
                        let all = strokes + (current.isEmpty ? [] : [current])
                        for stroke in all where stroke.count > 1 {
                            var path = Path()
                            path.move(to: viewPoint(stroke[0], fitted: fitted))
                            for point in stroke.dropFirst() {
                                path.addLine(to: viewPoint(point, fitted: fitted))
                            }
                            context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                current.append(imagePoint(value.location, fitted: fitted))
                            }
                            .onEnded { _ in
                                if current.count > 1 {
                                    strokes.append(current)
                                }
                                current = []
                            }
                    )
                }
            }

            HStack {
                if let savedURL {
                    Text("Saved: \(savedURL.lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Clear") { strokes.removeAll() }
                    .disabled(strokes.isEmpty)
                Button("Pin") { PinBoard.shared.pin(image: burned) }
                Button("Copy") { CaptureOutput.copyToClipboard(burned) }
                    .keyboardShortcut("c", modifiers: .command)
            }
        }
        .padding(16)
    }

    private var burned: CGImage {
        MarkupBurn.burn(strokes: strokes, into: image)
    }

    private func aspectFit(imageSize: CGSize, in box: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, box.width > 0, box.height > 0 else {
            return .zero
        }
        let scale = min(box.width / imageSize.width, box.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (box.width - size.width) / 2,
            y: (box.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func imagePoint(_ view: CGPoint, fitted: CGRect) -> CGPoint {
        guard fitted.width > 1, fitted.height > 1 else { return .zero }
        let x = (view.x - fitted.minX) / fitted.width * CGFloat(image.width)
        let y = (view.y - fitted.minY) / fitted.height * CGFloat(image.height)
        return CGPoint(
            x: min(max(0, x), CGFloat(image.width)),
            y: min(max(0, y), CGFloat(image.height))
        )
    }

    private func viewPoint(_ imagePoint: CGPoint, fitted: CGRect) -> CGPoint {
        CGPoint(
            x: fitted.minX + imagePoint.x / CGFloat(image.width) * fitted.width,
            y: fitted.minY + imagePoint.y / CGFloat(image.height) * fitted.height
        )
    }
}
