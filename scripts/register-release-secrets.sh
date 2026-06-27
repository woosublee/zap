#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

IDENTITY="${IDENTITY:-zap}"
CERTIFICATE_SECRET="${CERTIFICATE_SECRET:-ZAP_CERTIFICATE_BASE64}"
CERTIFICATE_PASSWORD_SECRET="${CERTIFICATE_PASSWORD_SECRET:-ZAP_CERTIFICATE_PASSWORD}"
SPARKLE_SECRET="${SPARKLE_SECRET:-SPARKLE_PRIVATE_KEY}"
SPARKLE_KEYCHAIN_SERVICE="${SPARKLE_KEYCHAIN_SERVICE:-https://sparkle-project.org}"
SPARKLE_KEYCHAIN_ACCOUNT="${SPARKLE_KEYCHAIN_ACCOUNT:-com.woosublee.Zap.sparkle.ed25519}"

if ! command -v gh >/dev/null 2>&1; then
  fail "gh CLI is required"
fi

if ! gh auth status >/dev/null 2>&1; then
  fail "gh CLI is not authenticated"
fi

REPOSITORY="${REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
existing_secrets="$(gh secret list --repo "$REPOSITORY" --json name --jq '.[].name' 2>/dev/null || true)"
if printf '%s\n' "$existing_secrets" | grep -Eq "^(${CERTIFICATE_SECRET}|${CERTIFICATE_PASSWORD_SECRET})$"; then
  if [[ "${ZAP_ROTATE_CERTIFICATE:-}" != "1" ]]; then
    fail "${CERTIFICATE_SECRET} or ${CERTIFICATE_PASSWORD_SECRET} already exists for ${REPOSITORY}. Set ZAP_ROTATE_CERTIFICATE=1 only if you intentionally want to rotate the CI signing certificate."
  fi
fi

if ! make -s check-eddsa-key >/dev/null; then
  fail "Sparkle private key is missing or does not match Info.plist. Run make generate-eddsa-key and keep Info.plist SUPublicEDKey in sync."
fi

sparkle_private_key="$(security find-generic-password -s "$SPARKLE_KEYCHAIN_SERVICE" -a "$SPARKLE_KEYCHAIN_ACCOUNT" -w 2>/dev/null)" || \
  fail "Sparkle private key is missing from Keychain: service=$SPARKLE_KEYCHAIN_SERVICE account=$SPARKLE_KEYCHAIN_ACCOUNT"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

if [[ -n "${ZAP_CERTIFICATE_P12:-}" ]]; then
  [[ -f "$ZAP_CERTIFICATE_P12" ]] || fail "ZAP_CERTIFICATE_P12 does not exist: $ZAP_CERTIFICATE_P12"
  [[ -n "${ZAP_CERTIFICATE_PASSWORD:-}" ]] || fail "ZAP_CERTIFICATE_PASSWORD is required when ZAP_CERTIFICATE_P12 is set"
  certificate_path="$ZAP_CERTIFICATE_P12"
  certificate_password="$ZAP_CERTIFICATE_PASSWORD"
else
  certificate_password="${ZAP_CERTIFICATE_PASSWORD:-$(openssl rand -base64 24)}"
  openssl_config="$tmpdir/openssl.cnf"
  certificate_key="$tmpdir/${IDENTITY}.key"
  certificate_crt="$tmpdir/${IDENTITY}.crt"
  certificate_path="$tmpdir/${IDENTITY}.p12"

  cat > "$openssl_config" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = ${IDENTITY}
[v3_req]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$certificate_key" \
    -out "$certificate_crt" \
    -config "$openssl_config" \
    >/dev/null 2>&1

  openssl pkcs12 -legacy -export \
    -passout "pass:${certificate_password}" \
    -inkey "$certificate_key" \
    -in "$certificate_crt" \
    -out "$certificate_path" \
    -name "$IDENTITY" \
    >/dev/null 2>&1
fi

base64_certificate="$(base64 < "$certificate_path" | tr -d '\n')"

gh secret set "$CERTIFICATE_SECRET" --repo "$REPOSITORY" --body "$base64_certificate"
gh secret set "$CERTIFICATE_PASSWORD_SECRET" --repo "$REPOSITORY" --body "$certificate_password"
gh secret set "$SPARKLE_SECRET" --repo "$REPOSITORY" --body "$sparkle_private_key"

printf 'Registered GitHub secrets for %s: %s, %s, %s\n' \
  "$REPOSITORY" \
  "$CERTIFICATE_SECRET" \
  "$CERTIFICATE_PASSWORD_SECRET" \
  "$SPARKLE_SECRET"
