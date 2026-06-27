#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/verify-dmg.sh <path-to-dmg>" >&2
  exit 64
fi

dmg_path="$1"
app_name="${APP_NAME:-Zap}"
last_status=0

for attempt in 1 2 3; do
  if hdiutil verify "$dmg_path"; then
    last_status=0
    break
  else
    last_status=$?
  fi
  if [[ $attempt -lt 3 ]]; then
    sleep 2
  fi
done

if [[ $last_status -ne 0 ]]; then
  exit "$last_status"
fi

mount_dir="$(mktemp -d "/tmp/${app_name}.dmg.XXXXXX")"
cleanup() {
  hdiutil detach "$mount_dir" >/dev/null 2>&1 || \
    hdiutil detach -force "$mount_dir" >/dev/null 2>&1 || \
    true
  rm -rf "$mount_dir"
}
trap cleanup EXIT

hdiutil attach "$dmg_path" -mountpoint "$mount_dir" -nobrowse -quiet
app_path="$mount_dir/${app_name}.app"
[[ -d "$app_path" ]] || {
  echo "Missing app in DMG: ${app_name}.app" >&2
  exit 1
}
codesign --verify --deep --strict --verbose=2 "$app_path"
echo "DMG verification passed"
