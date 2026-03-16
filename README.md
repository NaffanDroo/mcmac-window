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

## Keyboard Shortcuts

| Keys | Action |
|------|--------|
| `⌃⌥ ←` | Left half |
| `⌃⌥ →` | Right half |
| `⌃⌥ ↑` | Top half |
| `⌃⌥ ↓` | Bottom half |
| `⌃⌥⌘ ←` | Top-left quarter |
| `⌃⌥⌘ →` | Top-right quarter |
| `⌃⌥⇧ ←` | Bottom-left quarter |
| `⌃⌥⇧ →` | Bottom-right quarter |
| `⌃⌥⌘⇧ ←` | Cycle thirds left |
| `⌃⌥⌘⇧ →` | Cycle thirds right |
| `⌃⌥⌘ ↑` | Left two thirds |
| `⌃⌥⌘ ↓` | Right two thirds |
| `⌃⌥ ↩` | Maximize |
| `⌃⌥ Space` | Center (65% of screen) |

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
