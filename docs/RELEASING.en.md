# Releasing Zap

[한국어](RELEASING.md) | **English**

Automatic-update releases are built by the **Notarized Release** GitHub Actions workflow and published as GitHub Release assets. The app checks the Sparkle feed at:

```text
https://github.com/woosublee/zap/releases/latest/download/appcast.xml
```

Releases are signed with the `Developer ID Application: Woosub Lee (2L6ZW98RCP)` identity using the hardened runtime and a secure timestamp. The app is notarized and stapled before it is packaged, then the DMG is signed, notarized, stapled, and checked with Gatekeeper. The Sparkle EdDSA signature in `appcast.xml` is generated last, from the stapled DMG.

Zap 0.1.11 and earlier were signed with a self-signed `zap` certificate. Sparkle accepts the change of code-signing identity because the EdDSA key (`SUPublicEDKey` in `Info.plist`) is unchanged, so those installs update normally. macOS ties Accessibility access to the signing identity, so existing users grant Accessibility access to Zap again once after that update. Never rotate the Sparkle key and the signing identity in the same release.

The release workflow requires these GitHub Secrets:

- `DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded `.p12` with the Developer ID Application certificate and its private key.
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`: password for that `.p12`.
- `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`: App Store Connect API key used by `notarytool`.
- `SPARKLE_PRIVATE_KEY`: Sparkle EdDSA private key for signing `appcast.xml`.

The committed Sparkle public key lives in `Info.plist` as `SUPublicEDKey`. The private key, `.p12`, and `.p8` must not be committed.

Use the canonical Keychain item for the Sparkle private key:

```zsh
make generate-eddsa-key
make check-eddsa-key
```

If you already have the Sparkle private key in a file, copy it into the canonical item instead of generating a new public key:

```zsh
security add-generic-password \
  -U \
  -s "https://sparkle-project.org" \
  -a "com.woosublee.Zap.sparkle.ed25519" \
  -l "Private key for signing Sparkle updates" \
  -D "private key" \
  -j "Public key (SUPublicEDKey value) for this key is:\n\n$(plutil -extract SUPublicEDKey raw Info.plist)" \
  -w "$(cat build/sparkle_private_key.txt)"
```

Export the Developer ID Application identity from Keychain Access as a `.p12`, then register the GitHub Secrets from the local machine:

```zsh
DEVELOPER_ID_CERTIFICATE_P12=/path/to/developer-id.p12 \
DEVELOPER_ID_CERTIFICATE_PASSWORD=... \
ASC_ISSUER_ID=... \
scripts/register-release-secrets.sh
```

The script validates the `.p12` and the Sparkle private key, reads the API key from `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8` (override with `ASC_KEY_PATH` and `ASC_KEY_ID`), registers the secrets with `gh secret set`, and deletes the retired `ZAP_CERTIFICATE_BASE64` and `ZAP_CERTIFICATE_PASSWORD` secrets. It does not print the secret values.

Before running the workflow, update the version and build number in both `Info.plist` and `Makefile`. The workflow rejects releases when `make -s print-app-version`, `make -s print-build-number`, `make -s print-build-tag`, and the workflow input tag disagree.

Run the **Notarized Release** GitHub Actions workflow with a new tag such as `v1.2.3`. Do not create the tag first; the workflow checks that the remote tag does not already exist, builds from the workflow commit, signs and notarizes the app and DMG, generates `dist/appcast.xml`, creates the tag, and uploads both release assets:

- `Zap-<version>.dmg`
- `appcast.xml`

## Local fallback release

Local fallback releases require the Developer ID Application identity in the local Keychain and a `notarytool` keychain profile (`woosublee-notary` by default, override with `NOTARY_PROFILE`):

```zsh
security find-identity -v -p codesigning | grep "Developer ID Application"
xcrun notarytool store-credentials woosublee-notary --key <AuthKey.p8> --key-id <ASC_KEY_ID> --issuer <ASC_ISSUER_ID>
```

The fallback script validates the `v*` tag and the signing and notarization credentials, reads the version metadata from `Makefile`, builds, signs, notarizes, and verifies the DMG, generates `dist/appcast.xml` using the Keychain Sparkle private key, and uploads both release assets with the authenticated `gh` CLI:

```zsh
scripts/release-local.sh v1.2.3
```

By default, the fallback script does not clobber existing GitHub Release assets. Set `ALLOW_LOCAL_RELEASE_CLOBBER=1` only when you intentionally want to replace the DMG and appcast for an existing release.

