# CLAUDE.md — mcmac-window

A lightweight macOS window manager built in pure Swift with zero external dependencies. Runs as a menu-bar-only agent (`LSUIElement=true`) and snaps windows via global hotkeys.

## Build & Run

```bash
./build.sh          # release build → mcmac-window.app
./build.sh --debug  # debug build with -Onone -g
./run.sh            # kill existing instance, rebuild if stale, relaunch
./test.sh           # compile and run the full test suite
open mcmac-window.app
```

Requirements: macOS 13+, Xcode Command Line Tools (`xcode-select --install`).

The build is a **single `swiftc` invocation** — no Xcode project, no SPM, no external dependencies. Do not introduce either without explicit approval.

## Project Structure

```
Sources/
  WindowAction.swift    — snap action enum (no framework imports)
  Geometry.swift        — pure coordinate math; fully unit-tested
  WindowMover.swift     — AX read/write + focused-window lookup
  HotkeyManager.swift   — Carbon hotkey registration + dispatch
  AppDelegate.swift     — menu-bar status item + accessibility prompt
  main.swift            — NSApplication bootstrap (LSUIElement agent)
Tests/
  TestFramework.swift   — lightweight assertion helpers (no XCTest)
  GeometryTests.swift   — unit tests for all geometry (≥31 tests)
  WindowMoverTests.swift — integration tests via own-process AX
  TestRunner.swift      — @main entry point; exits 1 on failure
Info.plist              — LSUIElement=true, bundle id com.example.mcmac-window
build.sh / run.sh / test.sh
.github/workflows/ci.yml — runs on macos-15; geometry tests always pass; AX integration tests skip gracefully in headless CI
```

## Key Conventions

### Coordinate systems (critical)

macOS uses **two incompatible coordinate systems**:

| Context | Origin | Y direction |
|---------|--------|-------------|
| `NSScreen` / AppKit | bottom-left | up |
| `AXUIElement` | top-left | down |

**All conversion lives in `axRect(from:primaryScreenHeight:)` in `Geometry.swift`.** Never inline conversions elsewhere. Every geometry function operates in AX coordinates; the visibleFrame from `NSScreen` is converted once via `axRect` before any math.

### Focused window lookup

**Always use `NSWorkspace.shared.frontmostApplication`**, not `kAXFocusedApplicationAttribute` on the system-wide AX element.

Reason: Carbon's `RegisterEventHotKey` delivers hotkey events to our own process's event queue. At that moment the system-wide "focused application" attribute can transiently point at our LSUIElement agent rather than the target app. `NSWorkspace.frontmostApplication` tracks the last non-background app and never returns an LSUIElement.

### Hotkey registration

Use Carbon `RegisterEventHotKey`, not `NSEvent.addGlobalMonitorForEvents`. The NSEvent API requires a separate Input Monitoring permission and fails silently when it's not granted.

### No Xcode project / no SPM

The entire app compiles with one `swiftc` line. Keep it that way.

### Code signing

The bundle must be signed (even with ad-hoc `-`) so the bundle identifier (`com.example.mcmac-window`) matches the TCC entry macOS creates when the user enables Accessibility. `build.sh` does `codesign --force --sign - mcmac-window.app` automatically.

### Logging

Both `WindowMover.swift` and `HotkeyManager.swift` log to `/tmp/mcmac-window.log`. Use `tail -f /tmp/mcmac-window.log` to debug live. Log with the file-local helpers `mlog()` / `hlog()`.

## Adding a New Snap Action (checklist)

1. Add a case to `WindowAction` in `Sources/WindowAction.swift`.
2. Add the geometry branch in `computeTargetRect`'s `switch` in `Sources/Geometry.swift`.
3. Add a `Binding` entry in `HotkeyManager.bindings` in `Sources/HotkeyManager.swift` with the key code, Carbon modifier mask, and display string.
4. Add a unit test in `Tests/GeometryTests.swift` with exact expected pixel values.
5. Optionally add an integration test in `Tests/WindowMoverTests.swift`.

## Test Framework

The project has a zero-dependency custom test framework (no XCTest):

- `assertEq(_:_:tol:)` — floating-point equality with tolerance
- `assertEq(_:_:)` — `CGRect` and generic `Equatable` equality
- `assertTrue(_:)` — boolean assertion
- `skip(_:)` — throws `Skip.because` to skip a test without failing

Tests that require a real screen or Accessibility permission call `try skip("reason")` and are counted as skipped (not failed). This is how CI stays green in headless environments.

Run tests: `./test.sh`. Exit code 0 = all passing (skips don't count as failures).

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on `macos-15` for every push and PR. Steps: checkout → select Xcode → `./build.sh` → `./test.sh`. Integration tests that need a real screen or AX permission skip gracefully.

## Keyboard Shortcuts Reference

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
| `⌃⌥ ↩` | Maximize |
| `⌃⌥ Space` | Center (65% of screen) |

All actions apply to whichever screen the frontmost window currently occupies.
