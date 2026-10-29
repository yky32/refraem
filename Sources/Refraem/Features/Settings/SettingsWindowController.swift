import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let host = NSHostingView(rootView: SettingsView())
            let size = NSSize(width: 460, height: 560)

            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "\(Brand.name) Settings"
            window.isRestorable = false
            window.contentMinSize = NSSize(width: 420, height: 460)
            window.contentMaxSize = NSSize(width: 560, height: 760)
            window.contentView = host
            window.setContentSize(size)
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct SettingsView: View {
    @State private var recording: UtilityAction?
    @State private var notice: String?
    @State private var revision = 0
    @State private var screenRecordingStatus = "Checking…"
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private var versionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            permissions
            shortcutHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(HotkeyStore.groups.enumerated()), id: \.offset) { _, group in
                        shortcutGroup(group.title, group.actions)
                    }
                }
                .padding(.bottom, 4)
            }
            footer
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onDisappear { recording = nil }
        .task { screenRecordingStatus = await ScreenRecordingAccess.statusLabel() }
        .background(recorder)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let icon = BrandIcon.colorMarkImage() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Brand.name)
                    .font(.title3.weight(.semibold))
                Text(Brand.tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Brand.spokenHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var permissions: some View {
        VStack(spacing: 0) {
            permissionRow(title: "Accessibility", detail: "Move and resize windows", anchor: "Accessibility")
            Divider()
            permissionRow(
                title: "Screen Recording",
                detail: "Screenshots and recording · \(screenRecordingStatus)",
                anchor: "ScreenCapture"
            )
            Divider()
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at Startup")
                        .font(.body.weight(.medium))
                    Text("Open Refraem when you log in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { launchAtLogin },
                    set: { next in
                        if LaunchAtLogin.setEnabled(next) {
                            launchAtLogin = next
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        )
    }

    private var shortcutHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Shortcuts")
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    HotkeyStore.shared.reset()
                    recording = nil
                    notice = nil
                    revision += 1
                }
                .controlSize(.small)
            }
            Text(recording == nil
                ? "Click a shortcut, then press the new keys. Delete clears it."
                : "Press the new shortcut. Escape cancels. Delete clears it.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func shortcutGroup(_ title: String, _ actions: [UtilityAction]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                if index > 0 { Divider().padding(.leading, 12) }
                shortcutRow(action)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        )
        .id(revision)
    }

    private func shortcutRow(_ action: UtilityAction) -> some View {
        let hotkey = HotkeyStore.shared.binding(for: action)
        let isRecording = recording == action
        return HStack(spacing: 12) {
            Text(action.settingsTitle)
                .font(.body)
            Spacer(minLength: 8)
            Button(isRecording ? "Press keys…" : (hotkey?.shortcutLabel ?? "None")) {
                notice = nil
                recording = isRecording ? nil : action
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var recorder: some View {
        if recording != nil {
            ShortcutCatcher(
                onCancel: { recording = nil },
                onClear: {
                    guard let recording else { return }
                    HotkeyStore.shared.set(nil, for: recording)
                    notice = "\(recording.settingsTitle) has no shortcut."
                    self.recording = nil
                    revision += 1
                },
                onRecord: { event in
                    guard let recording else { return }
                    let hotkey = GlobalHotkey(event: event)
                    let previous = HotkeyStore.customizable.first {
                        $0 != recording && HotkeyStore.shared.binding(for: $0)?.sameCombo(as: hotkey) == true
                    }
                    HotkeyStore.shared.set(hotkey, for: recording)
                    if let previous {
                        notice = "\(previous.settingsTitle) no longer uses \(hotkey.shortcutLabel)."
                    } else {
                        notice = nil
                    }
                    self.recording = nil
                    revision += 1
                }
            )
            .frame(width: 0, height: 0)
        }
    }

    private var footer: some View {
        HStack {
            Text("Saves to Pictures/Refraem")
            Spacer(minLength: 8)
            Text(versionLine)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func permissionRow(title: String, detail: String, anchor: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Open") {
                openPrivacy(anchor)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct ShortcutCatcher: NSViewRepresentable {
    var onCancel: () -> Void
    var onClear: () -> Void
    var onRecord: (NSEvent) -> Void

    func makeNSView(context: Context) -> ShortcutCatcherView {
        let view = ShortcutCatcherView()
        view.onCancel = onCancel
        view.onClear = onClear
        view.onRecord = onRecord
        return view
    }

    func updateNSView(_ view: ShortcutCatcherView, context: Context) {
        view.onCancel = onCancel
        view.onClear = onClear
        view.onRecord = onRecord
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
    }
}

private final class ShortcutCatcherView: NSView {
    var onCancel: (() -> Void)?
    var onClear: (() -> Void)?
    var onRecord: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if event.keyCode == 51 && flags.isEmpty {
            onClear?()
            return
        }
        guard !flags.isEmpty else { return }
        onRecord?(event)
    }
}

private extension SettingsView {
    func openPrivacy(_ anchor: String) {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_\(anchor)",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_\(anchor)",
        ]
        for raw in urls {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }
}
