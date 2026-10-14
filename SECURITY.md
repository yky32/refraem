# Security

Refraem runs **only on your Mac**. It uses **Accessibility** and **Screen Recording** to move windows and capture the display. **Screen content is not sent to a server** by this app.

## Official downloads

Install only from this repository:

- [Releases](https://github.com/yky32/refraem/releases) (tagged builds), or  
- [Actions → Artifacts](https://github.com/yky32/refraem/actions) from **`yky32/refraem`** on `main`.

Do not use builds from unknown forks or third-party sites. Confirm the app **bundle ID** matches the official Refraem release notes.

## Secrets (maintainers)

These must **never** be committed to git or uploaded to GitHub:

| Item | Where it belongs |
|------|------------------|
| App ID, Team ID, ASC API key, signing cert | [GitHub Actions Secrets](docs/GITHUB_SECRETS.md) or local `fastlane/.env` |
| Developer ID `.p12` | GitHub Secret `APPLE_CERTIFICATE_BASE64` (CI only) or macOS Keychain locally |

`fastlane/.env`, `*.p8`, `*.p12`, and similar paths are in `.gitignore`. The **Build** workflow on `main` does not use Apple credentials. **Release** (tag `v*`) uses Secrets for notarized DMGs.

## Reporting vulnerabilities

Do **not** post exploit details in public Issues. Use [GitHub Security Advisories](https://github.com/yky32/refraem/security/advisories) (private) or contact the maintainer via GitHub profile.
