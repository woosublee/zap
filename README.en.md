# Zap

[한국어](README.md) | **English**

A macOS app for opening apps, switching between them, and arranging windows from the keyboard.

Open your pinned Dock apps with `⌥1`–`⌥9`, give any app its own shortcut, and move the window you're looking at to a half, a corner, or another display without touching the mouse.

<p align="center">
  <img src="assets/screenshots/settings-apps.png" alt="Zap Settings Apps page" width="92%">
</p>
<p align="center">
  <img src="assets/screenshots/settings-windows.png" alt="Zap Settings Windows page" width="92%">
</p>

## Install

1. Download `Zap-<version>.dmg` from the [latest release](https://github.com/woosublee/zap/releases/latest).
2. Open the DMG and drag `Zap.app` into your `Applications` folder.
3. Launch Zap. Its icon appears in the menu bar.

Zap is notarized by Apple, so it opens without a warning. It lets you know automatically when a new version is available.

Requires macOS 13 Ventura or later.

## Features

### Dock app shortcuts

The first nine apps pinned to your Dock are mapped to number keys automatically.

- `⌥1` opens the first Dock app, or brings it to the front.
- `⌥2` does the same for the second app, and so on through `⌥9`.

Reorder your Dock and the shortcuts follow. You can change the modifier keys to any combination of `⌘` `⌃` `⌥` `⇧` in **Settings > Apps**.

### Custom app shortcuts

For apps that aren't in your Dock, or when you'd rather use something easier to remember than a number, add them in **Settings > Apps > Custom Apps**. Give each app any shortcut you like, and turn it off, change it, or remove it at any time.

### Window management

Move and resize the frontmost window with a single shortcut. These are the defaults; you can change or turn off each one in **Settings > Windows**.

| Action | Default shortcut |
| --- | --- |
| Center | `⌥⌘C` |
| Fullscreen | `⌥⌘F` |
| Left / right half | `⌥⌘←` / `⌥⌘→` |
| Top / bottom half | `⌥⌘↑` / `⌥⌘↓` |
| Upper left / upper right | `⌃⌘←` / `⌃⌘→` |
| Lower left / lower right | `⌃⇧⌘←` / `⌃⇧⌘→` |
| Previous / next third | `⌃⌥←` / `⌃⌥→` |
| Smaller / larger | `⌃⌥⇧←` / `⌃⌥⇧→` |
| Previous / next display | `⌃⌥⌘←` / `⌃⌥⌘→` |
| Undo / redo | `⌥⌘Z` / `⌥⇧⌘Z` |

Window management needs macOS **Accessibility** permission. See [Getting started](#getting-started) below.

### Finder shortcut

Press `⌥` + `` ` `` to open Finder, just like clicking Finder in the Dock. The modifier follows your Dock app shortcut setting. With a Korean input source the same key shows as `₩`, but the shortcut is tied to the physical key, so it works in any input source. Turn it on or off in **Settings > Apps**.

### Pause Zap in a specific app

If a Zap shortcut clashes with one in another app, set a "Toggle Zap for Current App" shortcut in **Settings > General**. It turns Zap shortcuts off and on for the app you're using right now.

## Getting started

- **Window permission:** To use window shortcuts, allow Zap in **System Settings > Privacy & Security > Accessibility**. Until you do, **Settings > Windows** shows a **Grant…** button that takes you there. Dock and custom app shortcuts work without this permission.
- **Launch at login:** Turn it on in **Settings > General** to start Zap when you log in.

## Menu bar

Click the menu bar icon for quick access to:

- **Quick Launch:** open Finder, your custom apps, and your Dock apps
- **Window Control:** run any window action
- Refresh Dock apps, check for updates, About Zap, Settings, and Quit

If you hide the menu bar icon, Zap appears in the Dock instead, and clicking its Dock icon opens Settings.

## Privacy

Zap runs entirely on your Mac. It doesn't use a server, doesn't collect usage data, and never sends your app list, window information, or shortcut settings anywhere. Your settings stay on your Mac.

Accessibility permission is used only to move and resize other apps' windows.

## Troubleshooting

- **Window shortcuts don't work.** Make sure Zap is turned on in **System Settings > Privacy & Security > Accessibility**. If it is and shortcuts still don't work, remove Zap from the list and add it again. If you updated from Zap 0.1.11 or earlier, you need to do this once.
- **A shortcut won't register.** macOS or another app may already be using it. Zap shows an error at the top of Settings; pick a different shortcut.
- **Some windows won't resize the way I expect.** Apps with a minimum or maximum window size can only be resized within the range macOS allows.

## For developers

See [docs/RELEASING.en.md](docs/RELEASING.en.md) for the release process.
