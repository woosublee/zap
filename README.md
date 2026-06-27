# Zap

Zap is a native macOS utility for opening apps, switching to them, and managing windows with global keyboard shortcuts.

It is built for people who keep their most-used apps in the Dock, prefer custom app shortcuts, and want keyboard-first window control. Zap can automatically map Dock apps to number shortcuts, register manual app shortcuts, and move or resize the frontmost window without reaching for the mouse.

## Screenshots

<p align="center">
  <img src="assets/screenshots/settings-automatic.png" alt="Zap Settings in Automatic mode" width="92%">
</p>
<p align="center">
  <img src="assets/screenshots/settings-window-management.png" alt="Zap Settings in Window Management mode" width="92%">
</p>

## Recent updates

- Added Window Management shortcuts for centering, fullscreen, halves, corners, thirds, resizing, display movement, undo, and redo.
- Reworked Settings into a sidebar with Automatic, Manual, Window Management, General, and About pages.
- Updated the menu bar experience with native Quick Launch and Window Control menus.

## What Zap does

Zap combines app launching and window control.

### Automatic Dock shortcuts

Automatic mode reads the apps pinned to your macOS Dock and maps the first nine apps to number keys.

For example, if the Dock shortcut modifier is set to `⌥`:

- `⌥1` opens or focuses the first pinned Dock app.
- `⌥2` opens or focuses the second pinned Dock app.
- The mapping continues through `⌥9`.

You can choose the modifier keys used with the number shortcuts from Settings. Zap supports `⌘`, `⌃`, `⌥`, and `⇧` combinations.

### Manual app shortcuts

Manual mode lets you add apps directly and assign custom global shortcuts to them.

This is useful when:

- an app is not pinned to your Dock;
- you want a more memorable shortcut for a specific app;
- you want a shortcut that is separate from the automatic Dock order.

Manual shortcuts can be enabled, disabled, re-recorded, or removed at any time.

### Window Management shortcuts

Window Management moves and resizes the frontmost window with customizable global shortcuts. The default set includes:

- `⌥⌘C` to center the active window;
- `⌥⌘F` to make it fullscreen;
- `⌥⌘←`, `⌥⌘→`, `⌥⌘↑`, and `⌥⌘↓` for half-screen layouts;
- corner placement shortcuts;
- previous and next display shortcuts;
- previous and next third shortcuts;
- larger and smaller resize shortcuts;
- undo and redo for window layout changes.

Window Management requires macOS Accessibility permission so Zap can move and resize other apps' windows. If permission has not been granted yet, Zap shows the permission state in Settings and locks the window shortcuts until access is available.

### Finder shortcut

Zap includes an optional Finder shortcut. When enabled, `⌥` plus the physical `₩` / `` ` `` key opens Finder using behavior similar to clicking Finder in the Dock.

The displayed key follows your current input source:

- English input source: `` ` ``
- Korean input source: `₩`

The shortcut is based on the physical key, so it continues to work across Korean and English input states.

## Menu bar and Dock behavior

By default, Zap runs as a menu bar app.

The native menu bar menu includes:

- Quick Launch for Finder, manual app shortcuts, and Dock number shortcuts;
- Window Control for Window Management actions;
- Refresh Dock Apps;
- Check for Updates;
- Settings;
- Quit.

If you hide the menu bar icon, Zap switches to a regular Dock app so Settings is still reachable. Clicking the Dock icon opens the Settings window.

## Settings

Zap Settings is organized into sidebar pages.

### Automatic

Use Automatic to configure Dock app number shortcuts, enable or disable the Finder shortcut, refresh the Dock app list, and review the current Dock app mapping.

### Manual

Use Manual to add app shortcuts, record custom shortcuts, enable or disable shortcuts, and remove shortcuts you no longer need.

### Window Management

Use Window Management to enable or disable window shortcuts, review shortcuts by category, record custom shortcuts for each action, reset shortcuts to their defaults, and check Accessibility permission status.

### General

Use General to request Accessibility permission, enable or disable launch at login, show or hide the menu bar icon, and check for updates.

### About

Use About to view the current app version, build number, and creator link.

Automatic, Manual, and Window Management shortcuts can be used together. If a shortcut conflicts with another registered shortcut, Zap shows a registration error.

## Privacy and permissions

Zap runs locally on your Mac.

It does not use a server, does not collect analytics, and does not send your app list, window information, or shortcut settings anywhere. App and shortcut settings are stored locally with `UserDefaults`.

Window Management uses macOS Accessibility APIs to move and resize other apps' windows. Granting Accessibility permission only enables local window-control behavior for Zap; it does not change Zap's data collection behavior.

## Cutting an automatic-update release

Automatic-update releases are built by the **Self-signed Release** GitHub Actions workflow and published as GitHub Release assets. The app checks the Sparkle feed at:

```text
https://github.com/woosublee/zap/releases/latest/download/appcast.xml
```

The release workflow requires these GitHub Secrets:

- `ZAP_CERTIFICATE_BASE64`: base64-encoded `.p12` for the self-signed `zap` code signing certificate, including its private key.
- `ZAP_CERTIFICATE_PASSWORD`: password for that `.p12`.
- `SPARKLE_PRIVATE_KEY`: Sparkle EdDSA private key for signing `appcast.xml`.

The committed Sparkle public key lives in `Info.plist` as `SUPublicEDKey`. The private key and `.p12` certificate export must not be committed.

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

After the local Sparkle keychain item is present, register the GitHub Secrets from the local machine:

```zsh
scripts/register-release-secrets.sh
```

The script validates that the Sparkle private key matches `Info.plist` and registers `ZAP_CERTIFICATE_BASE64`, `ZAP_CERTIFICATE_PASSWORD`, and `SPARKLE_PRIVATE_KEY` with `gh secret set`. By default it creates a CI-only self-signed `zap` `.p12`; if you already have a stable `.p12`, pass it with `ZAP_CERTIFICATE_P12=/path/to/zap.p12 ZAP_CERTIFICATE_PASSWORD=... scripts/register-release-secrets.sh`. Existing certificate secrets are not overwritten unless `ZAP_ROTATE_CERTIFICATE=1` is set intentionally. The script does not print the secret values.

Before running the workflow, update the version and build number in both `Info.plist` and `Makefile`. The workflow rejects releases when `make -s print-app-version`, `make -s print-build-number`, `make -s print-build-tag`, and the workflow input tag disagree.

Run the **Self-signed Release** GitHub Actions workflow with a new tag such as `v1.2.3`. Do not create the tag first; the workflow checks that the remote tag does not already exist, builds from the workflow commit, signs the app and DMG with the imported `zap` certificate, generates `dist/appcast.xml`, creates the tag, and uploads both release assets:

- `Zap-<version>.dmg`
- `appcast.xml`

This CI release is self-signed and non-notarized. It keeps the Sparkle update path compatible with local self-signed releases, but it does not remove first-launch Gatekeeper warnings for brand-new installs. A Developer ID signed and notarized release path can be introduced later.

### Local fallback release

Local fallback releases require a code signing identity named `zap` in the local Keychain. Create or confirm it before cutting a fallback release:

```zsh
make create-local-certificate
security find-identity -v -p codesigning | grep '"zap"'
```

The fallback script validates the `v*` tag, requires the local `zap` code signing identity, reads the version metadata from `Makefile`, builds and verifies the signed DMG, signs the DMG, generates `dist/appcast.xml` using the Keychain Sparkle private key, and uploads both release assets with the authenticated `gh` CLI:

```zsh
scripts/release-local.sh v1.2.3
```

By default, the fallback script does not clobber existing GitHub Release assets. Set `ALLOW_LOCAL_RELEASE_CLOBBER=1` only when you intentionally want to replace the DMG and appcast for an existing release.

## Notes

- Requires macOS 13 or later.
- Dock shortcuts depend on the current pinned Dock app order.
- Global shortcuts may conflict with shortcuts registered by macOS or other apps.
- Manual shortcuts are local to the current macOS user account.
- Window Management shortcuts require Accessibility permission.
- Some apps may limit how far macOS lets Zap move or resize their windows.
