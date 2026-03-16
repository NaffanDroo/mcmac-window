# CLAUDE.md — mcmac-window

A lightweight macOS window manager built in pure Swift with zero external dependencies. Runs as a menu-bar-only agent (`LSUIElement=true`) and snaps windows via global hotkeys.

## Build & Run

```bash
./setup.sh          # one-time: installs pre-commit + SwiftLint + git hooks
./build.sh          # release build → mcmac-window.app
./build.sh --debug  # debug build with -Onone -g
./run.sh            # kill existing instance, rebuild if stale, relaunch
./test.sh           # compile and run the full test suite
open mcmac-window.app
```

Requirements: macOS 13+, Xcode Command Line Tools (`xcode-select --install`), Homebrew.

The build is a **single `swiftc` invocation** — no Xcode project, no SPM, no external dependencies. Do not introduce either without explicit approval.

## Local Hooks (pre-commit)

`./setup.sh` installs three git hooks via the [pre-commit](https://pre-commit.com) framework:

| Stage | Hook | What it does |
|-------|------|-------------|
| `commit-msg` | `conventional-pre-commit` | Rejects commit messages that don't follow Conventional Commits format |
| `pre-commit` | `swiftlint --strict` | Lints staged `.swift` files against `.swiftlint.yml` |
| `pre-push` | build + warnings-as-errors + test | Full pipeline mirror of CI — catches failures before they reach the remote |

Run all hooks manually: `pre-commit run --all-files`

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

Four GitHub Actions workflows run on every push and PR:

| Workflow | What it checks |
|----------|---------------|
| `ci.yml` | `./build.sh` (release) + `./build.sh --warnings-as-errors` + `./test.sh` |
| `lint.yml` | `swiftlint --strict` against `.swiftlint.yml` |
| `pr-title.yml` | PR title follows Conventional Commits format |
| `release-please.yml` | On merge to `main`: auto-creates `CHANGELOG.md`, tags a release, attaches a signed `.app` zip |

All four checks must be green before a PR can be merged. Integration tests that need a real screen or AX permission skip gracefully in headless CI.

## Working with AI (guidelines for LLM contributors)

This section documents rules that are especially easy for an AI to accidentally violate. Every item here corresponds to a real failure mode.

### Hard rules — CI will catch these

- **No force casts or force unwraps.** Use `as?`, `guard let`, or `if let`. SwiftLint (`force_unwrapping` rule) will fail the lint check.
- **No compiler warnings.** The `--warnings-as-errors` CI pass turns every warning into a build failure. Fix the root cause; do not suppress with `// swiftlint:disable` or `@_silgen_name` tricks.
- **No Xcode project or SPM manifest.** The build is a single `swiftc` invocation. Adding `Package.swift` or `*.xcodeproj` will break `build.sh` and requires explicit human approval.
- **PR titles must follow Conventional Commits.** The `pr-title` workflow enforces this. release-please reads commit messages to build the changelog and decide version bumps — a badly-named PR title corrupts the release history.

### Hard rules — CI will NOT catch these (human review required)

- **Never inline coordinate-system conversions.** All AppKit↔AX conversion goes through `axRect(from:primaryScreenHeight:)` in `Geometry.swift`. Inlining a conversion elsewhere produces silent wrong-position bugs that only manifest on non-primary displays or non-standard menubar heights.
- **Never use `kAXFocusedApplicationAttribute` on the system-wide AX element.** Always use `NSWorkspace.shared.frontmostApplication`. See the comment in `WindowMover.swift` for the full explanation — this is a Carbon event-delivery race condition that is very hard to reproduce.
- **Never use `NSEvent.addGlobalMonitorForEvents` for hotkeys.** It silently does nothing without Input Monitoring permission. Use Carbon `RegisterEventHotKey`.
- **Never skip or weaken a test to make it pass.** Use `try skip("reason")` only when the test genuinely requires hardware (a real screen, AX permission). Do not lower tolerances or remove assertions to paper over a geometry bug.
- **Every new `WindowAction` case needs a geometry test.** The PR template checklist enforces this at review time. No case ships without exact pixel-value assertions in `Tests/GeometryTests.swift`.
- **Update `CLAUDE.md` keyboard shortcuts table for every new hotkey.** The table is the authoritative human-readable reference; the code is the machine-readable one. Both must stay in sync.

### Commit and PR hygiene

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). See `CONTRIBUTING.md` for the type table and examples.
- One logical change per commit. Do not batch unrelated fixes.
- Do not amend or force-push commits that have already been reviewed — open a new commit instead.
- Do not use `--no-verify` to bypass hooks or `--force` to bypass branch protection.
- **After every commit or code change, update the open PR description** to reflect the current state of the branch. Run `git diff main...HEAD --stat` and `git log main..HEAD --oneline` to get a full picture of all changes, then use `gh pr edit` to rewrite the title and body. The PR description is the canonical human-readable summary of the branch — it must stay in sync with the code.

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
| `⌃⌥⌘ ↑` | Left two thirds |
| `⌃⌥⌘ ↓` | Right two thirds |
| `⌃⌥ ↩` | Maximize |
| `⌃⌥ Space` | Center (65% of screen) |

All actions apply to whichever screen the frontmost window currently occupies.

### Push-through behaviour

Pressing the same directional hotkey a second time when the window is already
at its snap target moves the window to the **mirror position on the adjacent
screen** in that direction. For example:

- Middle screen, window at left half → press `⌃⌥ ←` again → right half of
  the left screen
- Middle screen, window at top-right quarter → press `⌃⌥⌘ →` again → top-left
  quarter of the right screen

Actions without a directional mirror (`⌃⌥ ↩` maximize, `⌃⌥ Space` center,
and the cycling thirds) do not push through.
