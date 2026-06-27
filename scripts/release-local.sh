#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

if [[ $# -ne 1 ]]; then
  fail "Usage: scripts/release-local.sh v1.2.3"
fi

RELEASE_TAG="$1"
[[ "$RELEASE_TAG" == v* ]] || fail "RELEASE_TAG must start with v: $RELEASE_TAG"

VERSION="${RELEASE_TAG#v}"
APP_VERSION="$(make -s print-app-version)"
BUILD_NUMBER="$(make -s print-build-number)"
BUILD_TAG="$(make -s print-build-tag)"
APPCAST_PATH="dist/appcast.xml"
DMG_PATH="dist/Zap-${VERSION}.dmg"
CODESIGN_IDENTITY="zap"
RELEASE_NOTES="Manual fallback release: self-signed, non-notarized DMG signed with the local zap code signing identity and Sparkle appcast."

[[ "$RELEASE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "RELEASE_TAG must use semantic versioning, for example v0.1.0"
[[ "$RELEASE_TAG" == "$BUILD_TAG" ]] || fail "RELEASE_TAG $RELEASE_TAG must match Makefile build tag $BUILD_TAG"
[[ "$VERSION" == "$APP_VERSION" ]] || fail "Release version $VERSION must match Makefile app version $APP_VERSION"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || fail "Build number must be a positive integer: $BUILD_NUMBER"

if ! security find-identity -v -p codesigning | grep -F "\"${CODESIGN_IDENTITY}\"" >/dev/null; then
  fail "${CODESIGN_IDENTITY} code signing identity is required. Confirm it exists with: security find-identity -v -p codesigning. This script does not create Keychain certificates automatically."
fi

REPOSITORY="${REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
export RELEASE_TAG VERSION BUILD_NUMBER APPCAST_PATH DMG_PATH REPOSITORY

make VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" BUILD_TAG="$RELEASE_TAG" CODESIGN_IDENTITY="$CODESIGN_IDENTITY" prepare-release-dmg
make -s check-eddsa-key
scripts/generate-sparkle-appcast.sh

gh release view "$RELEASE_TAG" --repo "$REPOSITORY" >/dev/null 2>&1 || \
  gh release create "$RELEASE_TAG" --repo "$REPOSITORY" --verify-tag --title "Zap $VERSION" --notes "$RELEASE_NOTES"

if [[ "${ALLOW_LOCAL_RELEASE_CLOBBER:-}" == "1" ]]; then
  gh release upload "$RELEASE_TAG" "$DMG_PATH" "$APPCAST_PATH" --repo "$REPOSITORY" --clobber
else
  gh release upload "$RELEASE_TAG" "$DMG_PATH" "$APPCAST_PATH" --repo "$REPOSITORY"
fi
