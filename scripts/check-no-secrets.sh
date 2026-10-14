#!/usr/bin/env bash
# Fail if git tracks files that should never be public.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bad=0
while IFS= read -r f; do
  echo "ERROR: tracked secret-like file: $f" >&2
  bad=1
done < <(git ls-files | grep -E '\.(p8|p12|pem|cer|mobileprovision|env)$|AuthKey_|/fastlane/\.env$|api_key\.p8' || true)

if git grep -E 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' -- '*.swift' '*.md' '*.yml' '*.sh' '*.rb' 'fastlane/*' 2>/dev/null; then
  echo "ERROR: private key material found in tracked files" >&2
  bad=1
fi

if [[ "$bad" -ne 0 ]]; then
  exit 1
fi
echo "No secret-like paths tracked in git."
