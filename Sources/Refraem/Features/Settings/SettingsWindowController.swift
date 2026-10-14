import AppKit

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let content = NSHostingView(rootView: SettingsPlaceholderView())
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window?.title = "\(Brand.name) Settings"
            window?.contentView = content
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

import SwiftUI

struct SettingsPlaceholderView: View {
    private var versionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                if let icon = BrandIcon.colorMarkImage() {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 56, height: 56)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(Brand.name)
                        .font(.title2.weight(.semibold))
                    Text(Brand.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Brand.spokenHint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Permissions")
                    .font(.headline)
                Text("Enable Accessibility and Screen Recording in System Settings → Privacy & Security for layout, capture, and OCR.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Captures are saved to Pictures/Refraem.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(versionLine)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
