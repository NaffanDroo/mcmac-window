# McMac Window

> Lightweight macOS window manager — snap any window into place with a hotkey.

[![CI](https://github.com/NaffanDroo/mcmac-window/actions/workflows/ci.yml/badge.svg)](https://github.com/NaffanDroo/mcmac-window/actions/workflows/ci.yml)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![No dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)

Inspired by [Rectangle](https://rectangleapp.com), built in pure Swift with a single `swiftc` invocation — no Xcode project, no package manager, no external dependencies.

## Requirements

- macOS 13 or later
- Xcode Command Line Tools (`xcode-select --install`)
- Accessibility permission (prompted on first launch)

## Installation

```bash
./build.sh
open mcmac-window.app
```

Grant **Accessibility** permission when prompted (System Settings → Privacy & Security → Accessibility), then relaunch.

### Accessibility permission after a rebuild

Each rebuild produces a new binary. macOS ties the Accessibility permission to the code signature, so rebuilding invalidates the old grant and hotkeys stop working. If that happens:

```bash
tccutil reset Accessibility org.nathandrew.mcmac-window
```

Then relaunch — the app will prompt for permission again. If it doesn't prompt, run `./run.sh` to force a fresh launch.

## Keyboard Shortcuts

All actions apply to the frontmost window on whatever screen it currently occupies.

### Halves

| Keys | Action |
|------|--------|
| `⌃⌥ ←` | Left half |
| `⌃⌥ →` | Right half |
| `⌃⌥ ↑` | Top half |
| `⌃⌥ ↓` | Bottom half |

### Quarters

| Keys | Action |
|------|--------|
| `⌃⌥ U` | Top-left |
| `⌃⌥ I` | Top-right |
| `⌃⌥ J` | Bottom-left |
| `⌃⌥ K` | Bottom-right |

### Thirds

| Keys | Action |
|------|--------|
| `⌃⌥ D` | First third |
| `⌃⌥ F` | Center third |
| `⌃⌥ G` | Last third |
| `⌃⌥ E` | Left two thirds |
| `⌃⌥ T` | Right two thirds |

### Special

| Keys | Action |
|------|--------|
| `⌃⌥ ↩` | Maximize |
| `⌃⌥ C` | Center (65% of screen) |

### Push-through

Pressing a directional shortcut again when the window is already at its snap target moves it to the **mirror position on the adjacent screen**. For example, pressing `⌃⌥ ←` on a window already snapped to the left half moves it to the right half of the screen to the left.

Actions without a clear direction (Maximize, Center, and Thirds) do not push through.

## Troubleshooting

**Hotkeys not working?** Grant Accessibility permission in System Settings → Privacy & Security → Accessibility, then relaunch. After a rebuild, reset the permission first:

```bash
tccutil reset Accessibility org.nathandrew.mcmac-window
```

**Watching live logs:**

```bash
log stream --predicate 'subsystem == "org.nathandrew.mcmac-window"' --level debug
```

Or open **Console.app** and filter by subsystem `org.nathandrew.mcmac-window`. Logs record every hotkey event, which app was frontmost, whether the action was skipped (paused or ignored), and any AX errors.

You can also export a day's worth of logs from the menu bar via **Export Logs…**, which saves a plain-text `.log` file you can share for bug reports.

## Running Tests

```bash
./test.sh
```

## Project Structure

```
Sources/
  WindowAction.swift     — snap action enum
  Geometry.swift         — pure coordinate math (fully unit tested)
  WindowMover.swift      — AX window read/write + focusedWindow lookup
  HotkeyManager.swift    — Carbon RegisterEventHotKey registration
  AppDelegate.swift      — menu bar item, accessibility prompt
  main.swift             — NSApplication bootstrap
Tests/
  TestFramework.swift    — zero-dependency assertion helpers
  GeometryTests.swift    — unit tests for all geometry logic
  WindowMoverTests.swift — integration tests (own-process AX)
  TestRunner.swift       — test entry point
Resources/
  AppIcon.icns           — app and DMG volume icon
scripts/
  make_dmg.sh            — builds a distribution DMG
  test_dmg.sh            — verifies DMG layout and appearance
Info.plist               — LSUIElement=true (no Dock icon)
build.sh / run.sh / test.sh
```
