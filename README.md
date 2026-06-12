# Zap

Zap is a native macOS utility for opening apps, switching to them, and managing windows with global keyboard shortcuts.

It is built for people who keep their most-used apps in the Dock, prefer custom app shortcuts, and want keyboard-first window control. Zap can automatically map Dock apps to number shortcuts, register manual app shortcuts, and move or resize the frontmost window without reaching for the mouse.

## Screenshots

<p align="center">
  <img src="assets/screenshots/settings-automatic.png" alt="Zap Settings in Automatic mode" width="45%">
  <img src="assets/screenshots/settings-manual.png" alt="Zap Settings in Manual mode" width="45%">
</p>
<p align="center">
  <img src="assets/screenshots/settings-window-management.png" alt="Zap Settings in Window Management mode" width="92%">
</p>

## Recent updates

- Added Window Management shortcuts for centering, fullscreen, halves, corners, thirds, resizing, display movement, undo, and redo.
- Reworked Settings into a sidebar with Automatic, Manual, Window Management, General, and About pages.
- Updated the menu bar experience with native Quick Launch and Window Control menus.
- Updated release metadata and Sparkle appcast examples to version `0.1.4`, build `5`.

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

## Finder shortcut

Zap includes an optional Finder shortcut.

When enabled, `⌥` plus the physical `₩` / `` ` `` key opens Finder using behavior similar to clicking Finder in the Dock. The displayed key follows your current input source:

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

Use Automatic to:

- configure Dock app number shortcuts;
- enable or disable the Finder shortcut;
- refresh the Dock app list;
- review the current Dock app mapping.

### Manual

Use Manual to:

- add an app shortcut;
- record a custom shortcut;
- enable or disable a shortcut;
- remove shortcuts you no longer need.

### Window Management

Use Window Management to:

- enable or disable window shortcuts;
- review shortcuts grouped by Positioning, Display, Sizing, and History;
- record custom shortcuts for each action;
- reset all window shortcuts to their defaults;
- see whether Accessibility permission is currently granted.

### General

Use General to:

- request Accessibility permission;
- enable or disable launch at login;
- show or hide the menu bar icon;
- check for Sparkle updates.

### About

Use About to view the current app version, build number, and creator link.

Automatic, Manual, and Window Management shortcuts can be used together. If a shortcut conflicts with another registered shortcut, Zap shows a registration error.

## Privacy and permissions

Zap runs locally on your Mac.

It does not use a server, does not collect analytics, and does not send your app list, window information, or shortcut settings anywhere. App and shortcut settings are stored locally with `UserDefaults`.

Window Management uses macOS Accessibility APIs to move and resize other apps' windows. Granting Accessibility permission only enables local window-control behavior for Zap; it does not change Zap's data collection behavior.

## Build and run

Requirements:

- macOS 13 or later
- Swift 5.10 or later
- Xcode Command Line Tools

Run tests:

```sh
swift test
```

Build and run the development app:

```sh
make dev-run
```

Build, sign, and verify the development app:

```sh
make dev-verify
```

Build, sign, and verify the production app:

```sh
make prod-verify
```

Install the production app to `/Applications`:

```sh
make prod-install
```

The development app bundle is created at `/tmp/zap-bundles/dev/Zap dev.app`.
The production app bundle is created at `/tmp/zap-bundles/prod/Zap.app`.

## Sparkle updates and release flow

Zap uses Sparkle 2.9.2 for automatic updates. Update archives referenced by the appcast are verified with Sparkle EdDSA signatures, while local app builds use a self-signed macOS code signing identity named `zap`.

Development and production builds use `CODESIGN_IDENTITY ?= zap` by default. Release-oriented targets inherit this through `RELEASE_CODESIGN_IDENTITY ?= $(CODESIGN_IDENTITY)`.

Sparkle automatic checks are enabled, automatic installs are disabled, and Zap does not set `SUUpdateCheckInterval`. Sparkle therefore uses its default automatic check interval of once per day.

### One-time local setup

Create the local self-signed signing certificate:

```sh
make create-local-certificate
```

Generate the Sparkle EdDSA key in Keychain:

```sh
make generate-eddsa-key
```

Because of Sparkle's official tool behavior, the private key is stored in Keychain using Sparkle's fixed label and service. Zap only customizes the Sparkle account name:

- label: `Private key for signing Sparkle updates`
- service: `https://sparkle-project.org`
- account: `com.woosublee.Zap.sparkle.ed25519`

The Sparkle EdDSA private key is not stored in this repository.

### Verification

Check that the local signing certificate exists:

```sh
make check-local-certificate
```

Check that the Sparkle EdDSA private key exists in Keychain and matches the `SUPublicEDKey` committed in `Info.plist`:

```sh
make check-eddsa-key
```

The matching public key is configured in the app's `Info.plist` as `SUPublicEDKey`:

```text
AHxDbDyUOqSlujzhZxsiHr89OwuBOgBiacMlFdCHTHs=
```

`SUFeedURL` points to the latest GitHub Release appcast asset:

```text
https://github.com/woosublee/zap/releases/latest/download/appcast.xml
```

### Generate release archive and appcast

Generate the Sparkle archive and appcast for a tagged release:

```sh
make appcast VERSION=0.1.4 BUILD_NUMBER=5 BUILD_TAG=v0.1.4
```

This creates ignored release artifacts:

- `dist/Zap-0.1.4.zip`
- `dist/Zap-0.1.4.dmg`
- `dist/appcast.xml`

Upload all three files to the GitHub Release matching `v0.1.4`. Sparkle reads `appcast.xml` from the latest GitHub Release asset URL configured in `SUFeedURL`; no GitHub Pages publishing is required.

## Notes

- Dock shortcuts depend on the current pinned Dock app order.
- Global shortcuts may conflict with shortcuts registered by macOS or other apps.
- Manual shortcuts are local to the current macOS user account.
- Window Management shortcuts require Accessibility permission.
- Some apps may limit how far macOS lets Zap move or resize their windows.
- Production update artifacts are built locally and published through GitHub Releases.
