# Zap

Zap is a native macOS utility for opening and switching to apps with global keyboard shortcuts.

It is built for people who keep their most-used apps in the Dock and want to reach them without moving their hands away from the keyboard. Zap can automatically map Dock apps to number shortcuts, and it also supports manually registered app shortcuts for anything that does not fit the Dock-based workflow.

## Screenshots

<p align="center">
  <img src="assets/screenshots/settings-automatic.png" alt="Zap Settings in Automatic mode" width="45%">
  <img src="assets/screenshots/settings-manual.png" alt="Zap Settings in Manual mode" width="45%">
</p>

## What Zap does

Zap gives you two ways to launch or focus apps.

### Automatic mode

Automatic mode reads the apps pinned to your macOS Dock and maps the first nine apps to number keys.

For example, if the Dock shortcut modifier is set to `⌥`:

- `⌥1` opens or focuses the first pinned Dock app.
- `⌥2` opens or focuses the second pinned Dock app.
- The mapping continues through `⌥9`.

You can choose the modifier keys used with the number shortcuts from Settings. Zap supports `⌘`, `⌃`, `⌥`, and `⇧` combinations.

### Manual mode

Manual mode lets you add apps directly and assign custom global shortcuts to them.

This is useful when:

- an app is not pinned to your Dock;
- you want a more memorable shortcut for a specific app;
- you want a shortcut that is separate from the automatic Dock order.

Manual shortcuts can be enabled, disabled, re-recorded, or removed at any time.

## Finder shortcut

Zap includes an optional Finder shortcut.

When enabled, `⌥` plus the physical `₩` / `` ` `` key opens Finder using behavior similar to clicking Finder in the Dock. The displayed key follows your current input source:

- English input source: `` ` ``
- Korean input source: `₩`

The shortcut is based on the physical key, so it continues to work across Korean and English input states.

## Menu bar and Dock behavior

By default, Zap runs as a menu bar app.

If you hide the menu bar icon, Zap switches to a regular Dock app so Settings is still reachable. Clicking the Dock icon opens the Settings window.

## Settings

Zap has two main Settings modes.

### Automatic

Use Automatic mode to:

- configure Dock app number shortcuts;
- enable or disable the Finder shortcut;
- refresh the Dock app list;
- review the current Dock app mapping.

### Manual

Use Manual mode to:

- add an app shortcut;
- record a custom shortcut;
- enable or disable a shortcut;
- remove shortcuts you no longer need.

Automatic and Manual shortcuts can be used together. If a shortcut conflicts with another registered shortcut, Zap shows a registration error.

## Privacy

Zap runs locally on your Mac.

It does not use a server, does not collect analytics, and does not send your app list or shortcut settings anywhere. App and shortcut settings are stored locally with `UserDefaults`.

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

## Notes

- Dock shortcuts depend on the current pinned Dock app order.
- Global shortcuts may conflict with shortcuts registered by macOS or other apps.
- Manual shortcuts are local to the current macOS user account.
- Zap is currently distributed as a locally built macOS app bundle.
