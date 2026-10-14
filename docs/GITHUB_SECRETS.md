# GitHub Secrets (Release workflow)

Add these under **Repository → Settings → Secrets and variables → Actions → New repository secret**.

Required for **`Release`** workflow (`release_dmg` via Fastlane):

| Secret | Example / notes |
|--------|------------------|
| `APP_IDENTIFIER` | `app.yky.refraem` |
| `FASTLANE_TEAM_ID` | Apple Team ID (10 characters) |
| `CODE_SIGN_IDENTITY` | Full name, e.g. `Developer ID Application: Your Name (TEAMID)` |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID from App Store Connect → Users and Access → Keys |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer UUID from the same page |
| `APP_STORE_CONNECT_API_KEY_P8` | **Entire** contents of the `.p8` file (multiline secret) |
| `APPLE_CERTIFICATE_BASE64` | Base64 of your **Developer ID Application** `.p12` export |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Any strong random string (temporary CI keychain only) |

## Create the certificate secret

On your Mac (once):

```bash
# Export Developer ID Application cert from Keychain as .p12, then:
base64 -i ~/Downloads/certs.p12 | pbcopy
# Paste into GitHub secret APPLE_CERTIFICATE_BASE64
```

## Ship a release

```bash
git tag v0.1.0
git push origin v0.1.0
```

Open **Actions → Release** → confirm success → download **`Refraem-*-*.dmg`** from **Releases**.

Push to `main` without a tag still builds an ad-hoc zip via the **Build** workflow (no secrets required).
