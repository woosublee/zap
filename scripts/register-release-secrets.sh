#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

CERTIFICATE_SECRET="${CERTIFICATE_SECRET:-DEVELOPER_ID_CERTIFICATE_BASE64}"
CERTIFICATE_PASSWORD_SECRET="${CERTIFICATE_PASSWORD_SECRET:-DEVELOPER_ID_CERTIFICATE_PASSWORD}"
SPARKLE_SECRET="${SPARKLE_SECRET:-SPARKLE_PRIVATE_KEY}"
SPARKLE_KEYCHAIN_SERVICE="${SPARKLE_KEYCHAIN_SERVICE:-https://sparkle-project.org}"
SPARKLE_KEYCHAIN_ACCOUNT="${SPARKLE_KEYCHAIN_ACCOUNT:-com.woosublee.Zap.sparkle.ed25519}"
# Secrets for the retired self-signed "zap" certificate. They are deleted once
# the Developer ID secrets are registered.
LEGACY_CERTIFICATE_SECRETS=(ZAP_CERTIFICATE_BASE64 ZAP_CERTIFICATE_PASSWORD)

if ! command -v gh >/dev/null 2>&1; then
  fail "gh CLI is required"
fi

if ! gh auth status >/dev/null 2>&1; then
  fail "gh CLI is not authenticated"
fi

[[ -n "${DEVELOPER_ID_CERTIFICATE_P12:-}" ]] || fail "DEVELOPER_ID_CERTIFICATE_P12 must point at the exported Developer ID Application .p12"
[[ -f "$DEVELOPER_ID_CERTIFICATE_P12" ]] || fail "DEVELOPER_ID_CERTIFICATE_P12 does not exist: $DEVELOPER_ID_CERTIFICATE_P12"
[[ -n "${DEVELOPER_ID_CERTIFICATE_PASSWORD:-}" ]] || fail "DEVELOPER_ID_CERTIFICATE_PASSWORD is required"
[[ -n "${ASC_ISSUER_ID:-}" ]] || fail "ASC_ISSUER_ID is required (App Store Connect > Users and Access > Integrations)"

if [[ -z "${ASC_KEY_PATH:-}" ]]; then
  shopt -s nullglob
  asc_keys=("$HOME"/.appstoreconnect/private_keys/AuthKey_*.p8)
  shopt -u nullglob
  [[ ${#asc_keys[@]} -eq 1 ]] || fail "Set ASC_KEY_PATH; found ${#asc_keys[@]} keys under ~/.appstoreconnect/private_keys"
  ASC_KEY_PATH="${asc_keys[0]}"
fi
[[ -f "$ASC_KEY_PATH" ]] || fail "ASC_KEY_PATH does not exist: $ASC_KEY_PATH"
if [[ -z "${ASC_KEY_ID:-}" ]]; then
  ASC_KEY_ID="$(basename "$ASC_KEY_PATH" .p8)"
  ASC_KEY_ID="${ASC_KEY_ID#AuthKey_}"
fi

REPOSITORY="${REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

existing_secrets="$(gh secret list --repo "$REPOSITORY" --json name --jq '.[].name')"

# The Sparkle key must never change, so an already registered secret is kept
# when this machine does not hold the key.
sparkle_private_key=""
if make -s check-eddsa-key >/dev/null 2>&1; then
  sparkle_private_key="$(security find-generic-password -s "$SPARKLE_KEYCHAIN_SERVICE" -a "$SPARKLE_KEYCHAIN_ACCOUNT" -w 2>/dev/null)" || \
    fail "Sparkle private key is missing from Keychain: service=$SPARKLE_KEYCHAIN_SERVICE account=$SPARKLE_KEYCHAIN_ACCOUNT"
elif ! printf '%s\n' "$existing_secrets" | grep -Fxq "$SPARKLE_SECRET"; then
  fail "Sparkle private key is missing or does not match Info.plist, and ${SPARKLE_SECRET} is not registered. Import the existing key; do not generate a new one."
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

certificate_password_file="$tmpdir/certificate-password.txt"
printf '%s' "$DEVELOPER_ID_CERTIFICATE_PASSWORD" > "$certificate_password_file"

# Keychain exports use legacy ciphers: OpenSSL 3 needs -legacy to read the key,
# while LibreSSL has no -legacy flag but reads it directly.
pkcs12_dump() {
  openssl pkcs12 "$@" -in "$DEVELOPER_ID_CERTIFICATE_P12" -passin "file:${certificate_password_file}" -nodes 2>/dev/null || true
}
private_key_pattern='BEGIN ([A-Z]+ )?PRIVATE KEY'
pkcs12_contents="$(pkcs12_dump)"
if ! grep -Eq "$private_key_pattern" <<<"$pkcs12_contents"; then
  pkcs12_contents="$(pkcs12_dump -legacy)"
fi

grep -Eq "$private_key_pattern" <<<"$pkcs12_contents" || \
  fail ".p12 must contain the Developer ID Application private key, and DEVELOPER_ID_CERTIFICATE_PASSWORD must open it"

certificate_subject="$(openssl x509 -noout -subject <<<"$pkcs12_contents" 2>/dev/null)" || \
  fail "Unable to read certificate from .p12"
case "$certificate_subject" in
  *"Developer ID Application"*) ;;
  *) fail ".p12 must contain a Developer ID Application certificate; got: ${certificate_subject}" ;;
esac

base64 < "$DEVELOPER_ID_CERTIFICATE_P12" | tr -d '\n' | gh secret set "$CERTIFICATE_SECRET" --repo "$REPOSITORY"
printf '%s' "$DEVELOPER_ID_CERTIFICATE_PASSWORD" | gh secret set "$CERTIFICATE_PASSWORD_SECRET" --repo "$REPOSITORY"
printf '%s' "$ASC_KEY_ID" | gh secret set ASC_KEY_ID --repo "$REPOSITORY"
printf '%s' "$ASC_ISSUER_ID" | gh secret set ASC_ISSUER_ID --repo "$REPOSITORY"
base64 < "$ASC_KEY_PATH" | tr -d '\n' | gh secret set ASC_KEY_P8_BASE64 --repo "$REPOSITORY"
if [[ -n "$sparkle_private_key" ]]; then
  printf '%s' "$sparkle_private_key" | gh secret set "$SPARKLE_SECRET" --repo "$REPOSITORY"
else
  printf 'Kept the registered %s secret; the Sparkle key is not in this Keychain.\n' "$SPARKLE_SECRET"
fi

printf 'Registered GitHub secrets for %s: %s, %s, ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64\n' \
  "$REPOSITORY" \
  "$CERTIFICATE_SECRET" \
  "$CERTIFICATE_PASSWORD_SECRET"

for legacy_secret in "${LEGACY_CERTIFICATE_SECRETS[@]}"; do
  if printf '%s\n' "$existing_secrets" | grep -Fxq "$legacy_secret"; then
    gh secret delete "$legacy_secret" --repo "$REPOSITORY"
    printf 'Deleted retired self-signed certificate secret: %s\n' "$legacy_secret"
  fi
done
