import AppKit

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let content = NSHostingView(rootView: SettingsPlaceholderView())
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let icon = BrandIcon.colorMarkImage() {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 48, height: 48)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(Brand.name)
                        .font(.title2.bold())
                    Text(Brand.spokenHint)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Permissions: enable Accessibility and Screen Recording for full functionality.")
                .foregroundStyle(.secondary)
            Text("Captures save to Pictures/Refraem. Next: screen record, scrolling capture, markup.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
