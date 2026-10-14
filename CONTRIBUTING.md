# Contributing to Refraem

Thanks for helping make Refraem better for everyone.

## Quick start

1. Fork and clone `https://github.com/yky32/refraem`
2. Open `Package.swift` in Xcode or run `swift run Refraem`
3. Make a focused change (one feature or fix per PR)
4. `./scripts/build-app.sh` locally before opening a PR

## Pull requests

- Describe **what** and **why** (screenshots or screen recordings help for UI)
- Keep diffs small; match existing Swift style in `Sources/Refraem`
- Do not commit secrets, certificates, or `vendor/bundle/`

## Releases (maintainers)

- **CI:** every push to `main` → Actions artifact zip
- **Public download:** tag semver `v0.1.0` → GitHub Release with zip (see `.github/workflows/release.yml`)

## Ideas we care about

- Layout edge cases (multi-monitor, Stage Manager, full-screen apps)
- Capture quality & speed (ScreenCaptureKit)
- Screen recording
- Markup / pin windows
- Notarized CI builds (Developer ID secrets)

Open an [issue](https://github.com/yky32/refraem/issues) before large refactors.
