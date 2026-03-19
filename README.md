# mcmac-window

Basic Mac Window manager, heavily created with Claude.

A lightweight macOS window manager inspired by [Rectangle](https://rectangleapp.com), built in pure Swift with zero external dependencies.

## Requirements

- macOS 13 or later
- Xcode Command Line Tools (`xcode-select --install`)
- Accessibility permission (prompted on first launch)

## Build & Run

```bash
./build.sh          # compile → mcmac-window.app
open mcmac-window.app
```

Grant **Accessibility** permission when prompted (System Settings → Privacy & Security → Accessibility), then relaunch.

### Accessibility permission after a rebuild

Each rebuild produces a new binary with a different code signature. macOS ties the Accessibility permission to the signature, so rebuilding invalidates the old grant and hotkeys stop working. If that happens:

```bash
tccutil reset Accessibility com.example.mcmac-window
```

Then relaunch the app — it will prompt for permission again. If it doesn't prompt, run `./run.sh` to force a fresh launch.

## Keyboard Shortcuts

| Keys | Action |
|------|--------|
| `⌃⌥ ←` | Left half |
| `⌃⌥ →` | Right half |
| `⌃⌥ ↑` | Top half |
| `⌃⌥ ↓` | Bottom half |
| `⌃⌥ U` | Top-left quarter |
| `⌃⌥ I` | Top-right quarter |
| `⌃⌥ J` | Bottom-left quarter |
| `⌃⌥ K` | Bottom-right quarter |
| `⌃⌥ D` | First third |
| `⌃⌥ F` | Center third |
| `⌃⌥ G` | Last third |
| `⌃⌥ E` | Left two thirds |
| `⌃⌥ T` | Right two thirds |
| `⌃⌥ ↩` | Maximize |
| `⌃⌥ C` | Center (65% of screen) |

All actions apply to the window on whichever screen it currently occupies.

## Running Tests

```bash
./test.sh
```

Zero external dependencies — only Xcode Command Line Tools required.

## Project Structure

```
Sources/
  WindowAction.swift   — snap action enum
  Geometry.swift       — pure coordinate math (fully unit tested)
  WindowMover.swift    — AX window read/write + focusedWindow lookup
  HotkeyManager.swift  — Carbon RegisterEventHotKey registration
  AppDelegate.swift    — menu bar item, accessibility prompt
  main.swift           — NSApplication bootstrap
Tests/
  TestFramework.swift  — zero-dependency assertion helpers
  GeometryTests.swift  — unit tests for all geometry logic (36 tests)
  WindowMoverTests.swift — integration tests (own-process AX)
  TestRunner.swift     — test entry point
Info.plist             — LSUIElement=true (no Dock icon)
build.sh / run.sh / test.sh
```
