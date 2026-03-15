# Contributing to mcmac-window

## Getting Started

```bash
git clone https://github.com/NaffanDroo/mcmac-window.git
cd mcmac-window
./build.sh && open mcmac-window.app
./test.sh
```

## Development Workflow

```bash
./run.sh     # kill old instance, rebuild if stale, relaunch
./test.sh    # run the full test suite
```

## Adding a New Snap Action

1. Add a case to `WindowAction` in [Sources/WindowAction.swift](Sources/WindowAction.swift).
2. Add the geometry in `computeTargetRect`'s switch in [Sources/Geometry.swift](Sources/Geometry.swift).
3. Add a binding in `HotkeyManager.bindings` in [Sources/HotkeyManager.swift](Sources/HotkeyManager.swift).
4. Add a unit test in [Tests/GeometryTests.swift](Tests/GeometryTests.swift) with exact expected values.

## Key Technical Constraints

**Coordinate systems** — `NSScreen` uses bottom-left origin (y-up); `AXUIElement` uses top-left origin (y-down). All conversion lives in `axRect(from:primaryScreenHeight:)` in `Geometry.swift`. Do not inline conversions elsewhere.

**Hotkey API** — Use Carbon's `RegisterEventHotKey`, not `NSEvent.addGlobalMonitorForEvents`. The NSEvent approach requires a separate Input Monitoring permission and fails silently when not granted.

**Focused window lookup** — Always use `NSWorkspace.shared.frontmostApplication` to find the target app. When a Carbon hotkey fires it is dispatched to our process's event queue; `kAXFocusedApplicationAttribute` on the system-wide AX element can transiently point at us (an LSUIElement agent) instead of the target app.

**No SPM, no Xcode project** — The build is a single `swiftc` invocation. External dependencies require explicit approval.

## Pull Requests

- Every new `WindowAction` case needs a geometry test.
- Run `./build.sh` and `./test.sh` before opening a PR.
