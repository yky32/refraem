import AppKit
import SwiftUI

@MainActor
final class CapturePreviewWindowController {
    static let shared = CapturePreviewWindowController()
    private var window: NSWindow?

    func show(image: CGImage, savedURL: URL?) {
        let screen = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1280, height: 800)
        let size = NSSize(
            width: min(screen.width * 0.78, max(980, CGFloat(image.width) * 0.62)),
            height: min(screen.height * 0.82, max(700, CGFloat(image.height) * 0.62 + 56))
        )
        let hosting = NSHostingView(rootView: CapturePreviewView(image: image, savedURL: savedURL))

        if window == nil {
            window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window?.title = "\(Brand.name) Capture"
            window?.minSize = NSSize(width: 720, height: 480)
            window?.titlebarAppearsTransparent = true
            window?.isMovableByWindowBackground = true
        }
        window?.appearance = NSAppearance(named: .darkAqua)
        window?.backgroundColor = NSColor(calibratedWhite: 0.09, alpha: 1)
        window?.contentView = hosting
        window?.setContentSize(size)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private enum EditorTool: String, CaseIterable, Identifiable {
    case arrow, line, text, rectangle, oval, step, highlight, pen, blur, pixelate, crop, pick

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .arrow: "arrow.up.right"
        case .line: "line.diagonal"
        case .text: "character.textbox"
        case .rectangle: "rectangle"
        case .oval: "circle"
        case .step: "1.circle"
        case .highlight: "highlighter"
        case .pen: "pencil.tip"
        case .blur: "drop.halffull"
        case .pixelate: "square.grid.3x3.fill"
        case .crop: "crop"
        case .pick: "eyedropper"
        }
    }

    var help: String {
        switch self {
        case .arrow: "Arrow"
        case .line: "Line"
        case .text: "Text"
        case .rectangle: "Rectangle"
        case .oval: "Oval"
        case .step: "Numbered step"
        case .highlight: "Highlight"
        case .pen: "Pen"
        case .blur: "Blur"
        case .pixelate: "Pixelate"
        case .crop: "Crop"
        case .pick: "Color pick"
        }
    }
}

private struct ScaleKey: PreferenceKey {
    static let defaultValue: CGFloat = 1
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CapturePreviewView: View {
    let savedURL: URL?

    @State private var picture: CGImage
    @State private var composite: CGImage
    @State private var marks: [MarkupItem] = []
    @State private var tool: EditorTool = .arrow
    @State private var ink = Color.black
    @State private var zoom: CGFloat = 1
    @State private var displayScale: CGFloat = 1
    @State private var nextStep = 1
    @State private var savedName: String
    @State private var copied = false
    @State private var dragOrigin: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var freehand: [CGPoint] = []
    @State private var textAnchor: CGPoint?
    @State private var textValue = ""
    @State private var cropRect: CGRect?
    @State private var backdrop: BackdropStyle = .off
    @State private var keyMonitor: Any?
    @FocusState private var textFocused: Bool

    init(image: CGImage, savedURL: URL?) {
        self.savedURL = savedURL
        _picture = State(initialValue: image)
        _composite = State(initialValue: image)
        _savedName = State(initialValue: savedURL?.lastPathComponent ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            canvas
        }
        .background(Color(white: 0.09))
        .onAppear(perform: installKeys)
        .onDisappear(perform: removeKeys)
        .onPreferenceChange(ScaleKey.self) { displayScale = $0 }
    }

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            toolbarRow
        }
        .background(Color(white: 0.12))
    }

    private var toolbarRow: some View {
        HStack(spacing: 6) {
            barButton("doc.on.doc", help: "Copy") { copyImage() }
            barButton("square.and.arrow.down", help: "Save a copy") { saveImage() }
            barButton("pin", help: "Pin") { PinBoard.shared.pin(image: exportImage) }
            barButton("arrow.uturn.backward", help: "Undo") { undo() }
                .disabled(marks.isEmpty)
                .opacity(marks.isEmpty ? 0.35 : 1)

            divider

            ForEach(EditorTool.allCases) { item in
                Button {
                    tool = item
                    if item != .text { textAnchor = nil }
                    if item != .crop { cropRect = nil }
                } label: {
                    Image(systemName: item.symbol)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 28, height: 26)
                        .background(
                            tool == item ? Color.white.opacity(0.16) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(tool == item ? 1 : 0.78))
                .help(item.help)
            }

            divider

            Button {
                backdrop = backdrop.next
            } label: {
                Image(systemName: backdrop == .off ? "rectangle.dashed" : "photo.on.rectangle.angled")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 26)
                    .background(
                        backdrop == .off ? Color.clear : Color.white.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.white.opacity(backdrop == .off ? 0.78 : 1))
            .help("Backdrop: \(backdrop.title)")

            divider

            ColorPicker("", selection: $ink, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.35), lineWidth: 1))
            Text(inkHex)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.72))
                .frame(width: 68, alignment: .leading)

            Text(statusLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(copied ? 0.95 : 0.55))
                .padding(.leading, 10)

            Text("\(picture.width)×\(picture.height) px")
                .padding(.leading, 8)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.72))

            barButton("minus.magnifyingglass", help: "Zoom out") {
                zoom = max(0.25, zoom / 1.25)
            }
            Text("\(Int((displayScale * 100).rounded()))%")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(width: 40)
            barButton("plus.magnifyingglass", help: "Zoom in") {
                zoom = min(6, zoom * 1.25)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 18)
            .padding(.horizontal, 4)
    }

    private var canvas: some View {
        GeometryReader { geo in
            let native = CGSize(width: max(picture.width, 1), height: max(picture.height, 1))
            let pixelPad = backdrop.padding(for: picture)
            let cardNative = CGSize(width: native.width + pixelPad * 2, height: native.height + pixelPad * 2)
            let margin: CGFloat = 32
            let available = CGSize(
                width: max(40, geo.size.width - margin * 2),
                height: max(40, geo.size.height - margin * 2)
            )
            let fit = min(available.width / cardNative.width, available.height / cardNative.height)
            let scale = max(0.05, fit * zoom)
            let imageSize = CGSize(width: native.width * scale, height: native.height * scale)
            let cardSize = CGSize(width: cardNative.width * scale, height: cardNative.height * scale)
            let overflows = cardSize.width > geo.size.width - 4 || cardSize.height > geo.size.height - 4

            Group {
                if overflows {
                    ScrollView([.horizontal, .vertical]) {
                        screenshot(imageSize: imageSize, cardSize: cardSize, scale: scale)
                    }
                } else {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            screenshot(imageSize: imageSize, cardSize: cardSize, scale: scale)
                            Spacer(minLength: 0)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Checkerboard())
            .preference(key: ScaleKey.self, value: scale)
        }
        .overlay(alignment: .bottom) {
            if !savedName.isEmpty {
                Text(savedName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.55), in: Capsule())
                    .padding(.bottom, 14)
            }
        }
    }

    private func screenshot(imageSize: CGSize, cardSize: CGSize, scale: CGFloat) -> some View {
        let radius = backdrop.radius(for: picture) * scale
        let photo = ZStack {
            Image(nsImage: NSImage(cgImage: composite, size: NSSize(width: picture.width, height: picture.height)))
                .resizable()
                .interpolation(.high)
                .frame(width: imageSize.width, height: imageSize.height)

            Canvas { context, _ in
                drawDraft(in: context, imageSize: imageSize)
                if let cropRect {
                    strokeRect(cropRect, in: context, imageSize: imageSize, color: .white, dashed: true)
                }
            }
            .frame(width: imageSize.width, height: imageSize.height)
            .highPriorityGesture(drawGesture(imageSize: imageSize))

            if let textAnchor, tool == .text {
                TextField("Text", text: $textValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: max(13, textSize * scale), weight: .semibold))
                    .foregroundStyle(ink)
                    .frame(width: 220)
                    .focused($textFocused)
                    .onSubmit(commitText)
                    .position(
                        x: textAnchor.x / CGFloat(picture.width) * imageSize.width + 110,
                        y: textAnchor.y / CGFloat(picture.height) * imageSize.height + 8
                    )
            }

            if cropRect != nil {
                Button("Crop") { applyCrop() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .position(cropButtonPosition(imageSize: imageSize))
                    .help("Enter to crop")
            }
        }
        .frame(width: imageSize.width, height: imageSize.height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))

        return ZStack {
            if backdrop != .off {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backdropFill)
                    .frame(width: cardSize.width, height: cardSize.height)
            }
            photo
                .shadow(color: .black.opacity(backdrop == .off ? 0.35 : 0.28), radius: backdrop == .off ? 18 : 28, y: 12)
        }
        .frame(width: cardSize.width, height: cardSize.height)
    }

    private var backdropFill: LinearGradient {
        switch backdrop {
        case .off, .light:
            LinearGradient(colors: [Color(white: 0.97), Color(white: 0.88)], startPoint: .top, endPoint: .bottom)
        case .dark:
            LinearGradient(colors: [Color(white: 0.24), Color(white: 0.10)], startPoint: .top, endPoint: .bottom)
        case .gradient:
            LinearGradient(
                colors: [Color(red: 0.94, green: 0.95, blue: 0.97), Color(red: 0.78, green: 0.82, blue: 0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var statusLabel: String {
        if copied { return tool == .pick ? inkHex : "Copied" }
        if tool == .pick { return "Click a pixel" }
        if cropRect != nil { return "Enter to crop" }
        return "Tab to copy"
    }

    private var inkHex: String {
        MarkupColor.from(NSColor(ink)).hex
    }

    private var strokeWidth: CGFloat {
        max(2, CGFloat(picture.width) / 480)
    }

    private var textSize: CGFloat {
        max(18, CGFloat(picture.width) / 52)
    }

    private func barButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 26)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white.opacity(0.86))
        .help(help)
    }

    private func drawGesture(imageSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = imagePoint(value.location, imageSize: imageSize)
                if tool == .text || tool == .step || tool == .pick { return }
                if dragOrigin == nil { dragOrigin = point }
                dragCurrent = point
                if tool == .pen || tool == .highlight {
                    freehand.append(point)
                }
            }
            .onEnded { value in
                let point = imagePoint(value.location, imageSize: imageSize)
                if tool == .text {
                    textAnchor = point
                    textValue = ""
                    textFocused = true
                    return
                }
                if tool == .pick {
                    pickColor(at: point)
                    return
                }
                if tool == .step {
                    commit(.step(nextStep, point, MarkupColor.from(NSColor(ink))))
                    nextStep += 1
                    return
                }
                finishDrag()
            }
    }

    private func finishDrag() {
        guard let origin = dragOrigin, let current = dragCurrent else {
            dragOrigin = nil
            dragCurrent = nil
            freehand = []
            return
        }
        let color = MarkupColor.from(NSColor(ink))
        let width = strokeWidth
        let distance = hypot(current.x - origin.x, current.y - origin.y)
        switch tool {
        case .pen:
            if freehand.count > 1 { commit(.pen(freehand, color, width)) }
        case .highlight:
            if freehand.count > 1 { commit(.highlight(freehand, color, width * 7)) }
        case .line where distance > 2:
            commit(.line(origin, current, color, width))
        case .arrow where distance > 2:
            commit(.arrow(origin, current, color, width))
        case .rectangle where distance > 2:
            commit(.rectangle(origin, current, color, width))
        case .oval where distance > 2:
            commit(.oval(origin, current, color, width))
        case .blur where distance > 4:
            commit(.blur(box(origin, current)))
        case .pixelate where distance > 4:
            commit(.pixelate(box(origin, current)))
        case .crop where distance > 4:
            cropRect = box(origin, current)
        default:
            break
        }
        dragOrigin = nil
        dragCurrent = nil
        freehand = []
    }

    private func commit(_ item: MarkupItem) {
        marks.append(item)
        composite = MarkupRenderer.burn(marks, into: picture)
    }

    private func commitText() {
        let string = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let textAnchor, !string.isEmpty {
            commit(.text(string, textAnchor, MarkupColor.from(NSColor(ink)), textSize))
        }
        textValue = ""
        textAnchor = nil
        textFocused = false
    }

    private func undo() {
        guard !marks.isEmpty else { return }
        marks.removeLast()
        composite = MarkupRenderer.burn(marks, into: picture)
    }

    private func applyCrop() {
        guard let cropRect, let cropped = MarkupRenderer.crop(composite, to: cropRect) else { return }
        picture = cropped
        composite = cropped
        marks = []
        self.cropRect = nil
        zoom = 1
    }

    private func pickColor(at point: CGPoint) {
        guard let color = MarkupRenderer.sample(composite, at: point) else { return }
        ink = Color(nsColor: color.nsColor)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(color.hex, forType: .string)
        copied = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            copied = false
        }
    }

    private var exportImage: CGImage {
        MarkupRenderer.present(composite, backdrop: backdrop)
    }

    private func copyImage() {
        CaptureOutput.copyToClipboard(exportImage)
        copied = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            copied = false
        }
    }

    private func saveImage() {
        guard let url = try? CaptureOutput.savePNG(exportImage) else { return }
        savedName = url.lastPathComponent
    }

    private func installKeys() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.window === selfHostWindow else { return event }
            if event.window?.firstResponder is NSTextView { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 48, flags.isEmpty {
                copyImage()
                return nil
            }
            if event.keyCode == 36 || event.keyCode == 76, cropRect != nil {
                applyCrop()
                return nil
            }
            if flags == .command, event.charactersIgnoringModifiers?.lowercased() == "z" {
                undo()
                return nil
            }
            return event
        }
    }

    private var selfHostWindow: NSWindow? {
        NSApp.windows.first { $0.title == "\(Brand.name) Capture" }
    }

    private func removeKeys() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }

    private func drawDraft(in context: GraphicsContext, imageSize: CGSize) {
        let color = ink
        let width = max(1.5, strokeWidth * imageSize.width / CGFloat(picture.width))
        switch tool {
        case .pen, .highlight:
            guard freehand.count > 1 else { return }
            var path = Path()
            path.move(to: viewPoint(freehand[0], imageSize: imageSize))
            for point in freehand.dropFirst() {
                path.addLine(to: viewPoint(point, imageSize: imageSize))
            }
            let inkWidth = tool == .highlight ? width * 7 : width
            context.stroke(
                path,
                with: .color(color.opacity(tool == .highlight ? 0.45 : 1)),
                style: StrokeStyle(lineWidth: inkWidth, lineCap: .round, lineJoin: .round)
            )
        case .line, .arrow:
            guard let origin = dragOrigin, let current = dragCurrent else { return }
            var path = Path()
            let start = viewPoint(origin, imageSize: imageSize)
            let end = viewPoint(current, imageSize: imageSize)
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            if tool == .arrow {
                context.fill(arrowHead(from: start, to: end, length: max(10, width * 4)), with: .color(color))
            }
        case .rectangle:
            guard let origin = dragOrigin, let current = dragCurrent else { return }
            strokeRect(box(origin, current), in: context, imageSize: imageSize, color: color, dashed: false)
        case .oval:
            guard let origin = dragOrigin, let current = dragCurrent else { return }
            let rect = viewRect(box(origin, current), imageSize: imageSize)
            context.stroke(Path(ellipseIn: rect), with: .color(color), style: StrokeStyle(lineWidth: width))
        case .blur, .pixelate, .crop:
            guard let origin = dragOrigin, let current = dragCurrent else { return }
            strokeRect(box(origin, current), in: context, imageSize: imageSize, color: .white, dashed: true)
        case .text, .step, .pick:
            break
        }
    }

    private func strokeRect(_ rect: CGRect, in context: GraphicsContext, imageSize: CGSize, color: Color, dashed: Bool) {
        let view = viewRect(rect, imageSize: imageSize)
        let style = StrokeStyle(lineWidth: 1.5, dash: dashed ? [5, 4] : [])
        context.stroke(Path(view), with: .color(color), style: style)
    }

    private func arrowHead(from: CGPoint, to: CGPoint, length: CGFloat) -> Path {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let left = CGPoint(x: to.x + length * cos(angle + .pi * 0.82), y: to.y + length * sin(angle + .pi * 0.82))
        let right = CGPoint(x: to.x + length * cos(angle - .pi * 0.82), y: to.y + length * sin(angle - .pi * 0.82))
        var path = Path()
        path.move(to: to)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }

    private func cropButtonPosition(imageSize: CGSize) -> CGPoint {
        guard let cropRect else { return .zero }
        let view = viewRect(cropRect, imageSize: imageSize)
        return CGPoint(x: view.midX, y: max(16, view.maxY - 18))
    }

    private func imagePoint(_ view: CGPoint, imageSize: CGSize) -> CGPoint {
        guard imageSize.width > 1, imageSize.height > 1 else { return .zero }
        let x = view.x / imageSize.width * CGFloat(picture.width)
        let y = view.y / imageSize.height * CGFloat(picture.height)
        return CGPoint(
            x: min(max(0, x), CGFloat(picture.width)),
            y: min(max(0, y), CGFloat(picture.height))
        )
    }

    private func viewPoint(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(
            x: point.x / CGFloat(picture.width) * imageSize.width,
            y: point.y / CGFloat(picture.height) * imageSize.height
        )
    }

    private func viewRect(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        let origin = viewPoint(CGPoint(x: rect.minX, y: rect.minY), imageSize: imageSize)
        let far = viewPoint(CGPoint(x: rect.maxX, y: rect.maxY), imageSize: imageSize)
        return CGRect(x: origin.x, y: origin.y, width: far.x - origin.x, height: far.y - origin.y)
    }

    private func box(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 16
            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                var col = 0
                var x: CGFloat = 0
                while x < size.width {
                    let shade: CGFloat = (row + col).isMultiple(of: 2) ? 0.16 : 0.125
                    context.fill(
                        Path(CGRect(x: x, y: y, width: cell, height: cell)),
                        with: .color(Color(white: shade))
                    )
                    x += cell
                    col += 1
                }
                y += cell
                row += 1
            }
        }
    }
}
