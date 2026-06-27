#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

CODESIGN_IDENTITY="zap"
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
existing_secrets="$(gh secret list --repo "$REPOSITORY" --json name --jq '.[].name')"
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

certificate_password_file="$tmpdir/certificate-password.txt"
if [[ -n "${ZAP_CERTIFICATE_PASSWORD:-}" ]]; then
  printf '%s' "$ZAP_CERTIFICATE_PASSWORD" > "$certificate_password_file"
else
  openssl rand -base64 24 > "$certificate_password_file"
fi
certificate_password="$(cat "$certificate_password_file")"

legacy_args=()
if openssl pkcs12 -help 2>&1 | grep -q -- '-legacy'; then
  legacy_args=(-legacy)
fi

if [[ -n "${ZAP_CERTIFICATE_P12:-}" ]]; then
  [[ -f "$ZAP_CERTIFICATE_P12" ]] || fail "ZAP_CERTIFICATE_P12 does not exist: $ZAP_CERTIFICATE_P12"
  [[ -n "${ZAP_CERTIFICATE_PASSWORD:-}" ]] || fail "ZAP_CERTIFICATE_PASSWORD is required when ZAP_CERTIFICATE_P12 is set"
  certificate_path="$ZAP_CERTIFICATE_P12"
else
  openssl_config="$tmpdir/openssl.cnf"
  certificate_key="$tmpdir/${CODESIGN_IDENTITY}.key"
  certificate_crt="$tmpdir/${CODESIGN_IDENTITY}.crt"
  certificate_path="$tmpdir/${CODESIGN_IDENTITY}.p12"

  cat > "$openssl_config" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = ${CODESIGN_IDENTITY}
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

  openssl pkcs12 "${legacy_args[@]}" -export \
    -passout "file:${certificate_password_file}" \
    -inkey "$certificate_key" \
    -in "$certificate_crt" \
    -out "$certificate_path" \
    -name "$CODESIGN_IDENTITY" \
    >/dev/null 2>&1
fi

certificate_subject="$(openssl pkcs12 "${legacy_args[@]}" -in "$certificate_path" -passin "file:${certificate_password_file}" -clcerts -nokeys 2>/dev/null | openssl x509 -noout -subject 2>/dev/null)" || \
  fail "Unable to read certificate from .p12"
case "$certificate_subject" in
  *"CN = ${CODESIGN_IDENTITY}"*|*"CN=${CODESIGN_IDENTITY}"*) ;;
  *) fail ".p12 certificate common name must be ${CODESIGN_IDENTITY}; got: ${certificate_subject}" ;;
esac

if ! openssl pkcs12 "${legacy_args[@]}" -in "$certificate_path" -passin "file:${certificate_password_file}" -nocerts -nodes 2>/dev/null | grep -Eq 'BEGIN (RSA |EC |)PRIVATE KEY'; then
  fail ".p12 must contain a private key for ${CODESIGN_IDENTITY}"
fi

base64_certificate="$(base64 < "$certificate_path" | tr -d '\n')"

printf '%s' "$base64_certificate" | gh secret set "$CERTIFICATE_SECRET" --repo "$REPOSITORY"
printf '%s' "$certificate_password" | gh secret set "$CERTIFICATE_PASSWORD_SECRET" --repo "$REPOSITORY"
printf '%s' "$sparkle_private_key" | gh secret set "$SPARKLE_SECRET" --repo "$REPOSITORY"

printf 'Registered GitHub secrets for %s: %s, %s, %s\n' \
  "$REPOSITORY" \
  "$CERTIFICATE_SECRET" \
  "$CERTIFICATE_PASSWORD_SECRET" \
  "$SPARKLE_SECRET"
