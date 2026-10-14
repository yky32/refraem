# Security

Refraem runs **only on your Mac**. It uses **Accessibility** and **Screen Recording** to move windows and capture the display. **Screen content is not sent to a server** by this app.

## Official downloads

Install only from this repository:

- [Releases](https://github.com/yky32/refraem/releases) (tagged builds), or  
- [Actions → Artifacts](https://github.com/yky32/refraem/actions) from **`yky32/refraem`** on `main`.

Do not use builds from unknown forks or third-party sites. Bundle ID: **`app.yky.refraem`**.

## Secrets (maintainers)

These must **never** be committed to git or uploaded to GitHub:

| Item | Where it belongs |
|------|------------------|
| Apple Team ID | `fastlane/.env` as `FASTLANE_TEAM_ID` (see `fastlane/.env.example`) |
| App Store Connect API key | `~/.appstoreconnect/api_key.p8` + env vars in `fastlane/.env` |
| Developer ID certificate / password | macOS Keychain, not the repo |
| GitHub tokens, passwords | GitHub Secrets (if CI notarization is added later), never in code |

`fastlane/.env`, `*.p8`, `*.p12`, and similar paths are in `.gitignore`. CI builds do **not** use your Apple credentials.

## Reporting vulnerabilities

Do **not** post exploit details in public Issues. Use [GitHub Security Advisories](https://github.com/yky32/refraem/security/advisories) (private) or contact the maintainer via GitHub profile.
