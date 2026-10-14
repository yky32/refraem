fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac package

```sh
[bundle exec] fastlane mac package
```

Release Swift build + Refraem.app under build/Refraem.app (ad-hoc sign unless CODE_SIGN_IDENTITY is set)

### mac install

```sh
[bundle exec] fastlane mac install
```

Package and copy to ~/Applications/Refraem.app

### mac notarize_release

```sh
[bundle exec] fastlane mac notarize_release
```

Developer ID sign (set CODE_SIGN_IDENTITY) + notarize + staple. Needs ASC API key like lid.

### mac dmg

```sh
[bundle exec] fastlane mac dmg
```

Create build/Refraem.dmg from packaged app (requires create-dmg: brew install create-dmg)

### mac zip_release

```sh
[bundle exec] fastlane mac zip_release
```

Zip notarized app for hosting (e.g. yky.app download)

### mac upload_testflight

```sh
[bundle exec] fastlane mac upload_testflight
```

Mac App Store archive (requires Refraem.xcodeproj — run after Xcode target is added)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
