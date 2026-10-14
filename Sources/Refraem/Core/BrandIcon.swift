import AppKit

enum BrandIcon {
    /// Menu bar status item image (template).
    @MainActor
    static func menuBarImage() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "refraem-mark", withExtension: "svg", subdirectory: "Brand"),
              let image = NSImage(contentsOf: url)
        else { return fallbackMenuBarImage() }

        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    @MainActor
    private static func fallbackMenuBarImage() -> NSImage? {
        let image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: Brand.name)
        image?.isTemplate = true
        return image
    }

    /// Color mark for Settings / About.
    @MainActor
    static func colorMarkImage() -> NSImage? {
        if let url = Bundle.module.url(forResource: "refraem-mark-color", withExtension: "svg", subdirectory: "Brand"),
           let image = NSImage(contentsOf: url)
        {
            image.size = NSSize(width: 48, height: 48)
            return image
        }
        if let url = Bundle.module.url(forResource: "refraem-app-icon", withExtension: "jpg", subdirectory: "Brand"),
           let image = NSImage(contentsOf: url)
        {
            image.size = NSSize(width: 48, height: 48)
            return image
        }
        return nil
    }
}
