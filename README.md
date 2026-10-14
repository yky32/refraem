# Refraem

One menu bar Mac app — **layout** · **capture** · **record** (record next).  
Pronounced like *Reframe*. Built to replace separate window + screenshot utilities with one fast, native tool.

| | |
|---|---|
| **Product** | Refraem |
| **Bundle ID** | `app.yky.refraem` |
| **Logo** | `Sources/Refraem/Resources/Brand/` |

## Run

```bash
open /Users/wayneyu/Documents/Development/Git/yky/refraem/Package.swift
```

Scheme **Refraem** → **My Mac** → Run (⌘R).

```bash
cd /Users/wayneyu/Documents/Development/Git/yky/refraem && swift run Refraem
```

### Permissions

1. **Accessibility** — layout snaps (^⌥ arrows, etc.)
2. **Screen Recording** — capture screen / area / OCR

### Shortcuts (global while Refraem is running)

| Action | Shortcut |
|--------|----------|
| Layout halves / corners / thirds | ^⌥ (same as Rectangle defaults) |
| Capture screen | ⇧⌘1 |
| Capture area | ⇧⌘2 |
| Recognize text | ^⌥⌘O |

Captures copy to clipboard, save to **Pictures/Refraem**, and open a preview window.

## Status

| Feature | Status |
|---------|--------|
| Layout snap | ✅ |
| Global hotkeys | ✅ |
| Capture screen / area | ✅ |
| OCR to clipboard | ✅ |
| Scrolling capture | 🔜 |
| Screen record | 🔜 |
| Markup editor | 🔜 |

## Fastlane (same pattern as [yky32/lid](https://github.com/yky32/lid))

Use **Homebrew Ruby** (same as lid CI) — system `/usr/bin/ruby` is too old:

```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
cd /Users/wayneyu/Documents/Development/Git/yky/refraem
bundle install          # gems in vendor/bundle
bundle exec fastlane mac package    # build/Refraem.app
bundle exec fastlane mac install    # ~/Applications/Refraem.app
```

Or if `fastlane` is already on your PATH: `fastlane mac package`

**Notarized download build** (Developer ID + ASC key at `~/.appstoreconnect/api_key.p8`):

```bash
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (3G34999H3A)"
export APP_STORE_CONNECT_API_KEY_ID="..."
export APP_STORE_CONNECT_ISSUER_ID="..."
bundle exec fastlane mac notarize_release
bundle exec fastlane mac dmg          # needs: brew install create-dmg
bundle exec fastlane mac zip_release
```

**TestFlight (Mac App Store)** — add `Refraem.xcodeproj` first, then `bundle exec fastlane mac upload_testflight`.

| Lane | Purpose |
|------|---------|
| `mac package` | Release `.app` in `build/` |
| `mac install` | Install to Applications |
| `mac notarize_release` | Sign + notarize + staple |
| `mac dmg` / `mac zip_release` | Ship artifacts |
| `mac upload_testflight` | App Store (after Xcode project) |
