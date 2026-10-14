#!/usr/bin/env bash
# Import Developer ID .p12 into a temporary keychain (GitHub Actions). Requires secrets:
#   APPLE_CERTIFICATE_BASE64, APPLE_CERTIFICATE_PASSWORD, KEYCHAIN_PASSWORD
set -euo pipefail

if [[ -z "${APPLE_CERTIFICATE_BASE64:-}" ]]; then
  echo "APPLE_CERTIFICATE_BASE64 not set — skip certificate import (ad-hoc sign only)." >&2
  exit 0
fi

: "${APPLE_CERTIFICATE_PASSWORD:?APPLE_CERTIFICATE_PASSWORD required when certificate is set}"
: "${KEYCHAIN_PASSWORD:?KEYCHAIN_PASSWORD required when certificate is set}"

CERT_PATH="${RUNNER_TEMP}/build_certificate.p12"
KEYCHAIN_PATH="${RUNNER_TEMP}/app-signing.keychain-db"

echo -n "$APPLE_CERTIFICATE_BASE64" | base64 --decode -o "$CERT_PATH"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERT_PATH" -P "$APPLE_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
security list-keychain -d user -s "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" || true
echo "Apple signing certificate imported."
