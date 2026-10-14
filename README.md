<p align="center">
  <img src="Sources/Refraem/Resources/Brand/refraem-mark-color.svg" width="96" alt="Refraem" />
</p>

<h1 align="center">Refraem</h1>

<p align="center">
  <strong>Window layout and screen capture in one menu bar app for Mac.</strong><br />
  Native Swift · macOS 14+ · No Electron
</p>

<p align="center">
  <em>Pronounced</em> <strong>Reframe</strong> <em>(ree-FRAME)</em>
</p>

<p align="center">
  <a href="https://github.com/yky32/refraem/actions/workflows/build.yml"><img src="https://github.com/yky32/refraem/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-000000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
</p>

<p align="center">
  <a href="https://github.com/yky32/refraem/releases"><strong>Download</strong></a>
  ·
  <a href="#install">Install</a>
  ·
  <a href="#shortcuts">Shortcuts</a>
  ·
  <a href="#develop">Develop</a>
</p>

---

## Overview

Refraem replaces a separate window manager and screenshot utility with **one menu bar presence**: snap windows, capture the display, and copy text from the screen—without leaving the menu bar.

| Capability | Details |
|------------|---------|
| **Layout** | Halves, thirds, quarters; global shortcuts (Rectangle-style ^⌥) |
| **Capture** | Full screen and region; ⇧⌘1 / ⇧⌘2 |
| **OCR** | Region to clipboard as text (^⌥⌘O) |
| **Record** | Planned |

Open source ([MIT](LICENSE)). Inspect, fork, and contribute on GitHub.

## Install

### Releases (recommended)

1. Download **`Refraem-*-macOS.zip`** from [Releases](https://github.com/yky32/refraem/releases).
2. Move **Refraem.app** to **Applications**.
3. Launch from the **menu bar** (no Dock icon).

> **No release yet?** Use [Actions → Artifacts](https://github.com/yky32/refraem/actions) after a `main` build, or tag `v0.1.0` for a GitHub Release.

**Gatekeeper:** CI builds are ad-hoc signed. On first open, use **Right-click → Open** if macOS prompts.

### Permissions

| Permission | Purpose |
|------------|---------|
| Accessibility | Resize and position windows (Layout) |
| Screen Recording | Screenshots and OCR |

Enable **Refraem** under **System Settings → Privacy & Security**.

## Shortcuts

Refraem must be running (menu bar icon visible).

| Action | Shortcut |
|--------|----------|
| Left / right / top / bottom half | ^⌥ ← → ↑ ↓ |
| Quarters | ^⌥ U · I · J · K |
| Thirds | ^⌥ D · F · G · E · T |
| Capture screen | ⇧⌘1 |
| Capture area | ⇧⌘2 |
| Recognize text (OCR) | ^⌥⌘O |

Captures go to the **clipboard**, **Pictures/Refraem**, and an optional preview window.

## Roadmap

| Feature | Status |
|---------|--------|
| Layout snap and global hotkeys | Shipped |
| Screen / area capture and OCR | Shipped |
| Scrolling capture | Planned |
| Screen recording | Planned |
| Markup and pin | Planned |
| Notarized release builds | Planned |

## Download from CI

| Event | Where |
|-------|--------|
| Push to `main` | [Actions](https://github.com/yky32/refraem/actions) → **Build** → **Artifacts** |
| Tag `v*` | [Releases](https://github.com/yky32/refraem/releases) |

Maintainers: `git tag v0.1.0 && git push origin v0.1.0`

## Develop

**Requirements:** macOS 14+, Xcode 15+ or Swift 6 toolchain

```bash
git clone https://github.com/yky32/refraem.git
cd refraem
open Package.swift    # Run in Xcode (⌘R)
# or: swift run Refraem
```

Local `.app`:

```bash
./scripts/build-app.sh ~/Applications/Refraem.app
```

Optional **Fastlane** ([yky32/lid](https://github.com/yky32/lid) pattern): `bundle install && bundle exec fastlane mac install`

See [CONTRIBUTING.md](CONTRIBUTING.md) for pull requests and releases.

## Brand

Marks and usage: [`Sources/Refraem/Resources/Brand/BRAND.md`](Sources/Refraem/Resources/Brand/BRAND.md) · Bundle ID `app.yky.refraem`

## License

[MIT](LICENSE)

---

<p align="center">
  <a href="https://github.com/yky32/refraem/issues">Issues & feedback</a>
  ·
  <a href="https://github.com/yky32">yky32</a>
</p>
