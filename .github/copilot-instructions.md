# Copilot Cloud Agent Instructions for mcmac-window

## 1) What this repository is

- `mcmac-window` is a lightweight macOS window manager in Swift.
- It provides hotkey-based window snapping actions (halves, quarters, thirds, maximize, center, push-through).
- No external dependencies; uses SwiftPM plus AppKit/Accessibility/Carbon.
- Targets macOS 13+ and uses Accessibility API.

## 2) Repo size and technology

- Language: Swift 5.9.
- Build system: Swift Package Manager (SPM), with shell wrappers (`build.sh`, `run.sh`, `test.sh`).
- Type: macOS native GUI utility (menu-bar LSUIElement agent).
- Toolchain: Xcode + Command Line Tools (Xcode app required for SwiftLint sourcekit).
- CI runs on macos-15.

## 3) Key files and locations

### Source structure

- `Sources/McMacWindowCore/WindowAction.swift` — enum for actions.
- `Sources/McMacWindowCore/Geometry.swift` — pure math ops + critical AX<->AppKit conversion in `axRect(from:primaryScreenHeight:)`.
- `Sources/McMacWindowCore/WindowMover.swift` — AX read/write + frontmost-app lookup.
- `Sources/McMacWindowCore/HotkeyManager.swift` — Carbon hotkey registrations and bindings.
- `Sources/McMacWindowCore/AppDelegate.swift` — status item + menu + amplify accessibility prompt.
- `Sources/McMacWindow/main.swift` — app bootstrap (LSUIElement agent).

### Tests

- `Tests/McMacWindowTests/GeometryTests.swift` — deterministic geometry tests.
- `Tests/McMacWindowTests/HotkeyManagerTests.swift` — hotkey binding expectations.
- `Tests/McMacWindowTests/PushThroughTests.swift` — screen-adjacent logic.
- `Tests/McMacWindowTests/WindowMoverTests.swift` — AX integration tests (skips or special handling in headless env).

### Infra and checks

- `Package.swift` — SPM manifest.
- `.github/workflows/ci.yml` — run build, warnings-as-errors, test, make_dmg, test_dmg (on main push/PR).
- `CONTRIBUTING.md` — commit message rules and development checklists.
- `CLAUDE.md` — engineering “source of truth” for rules, coordinate system, and conventions.
- `scripts/make_dmg.sh`, `scripts/test_dmg.sh` — DMG packaging and verification.

## 4) Build + bootstrap + run + test commands

### 4.1 Setup (one-time local dev)

- `./setup.sh`
- requires `brew`, full Xcode installed and selected (`sudo xcode-select -s /Applications/Xcode.app`).
- Installs `pre-commit`, `swiftlint`, and git hooks (`pre-commit`, `commit-msg`, `pre-push`).

### 4.2 Build

- `./build.sh` (release build, fast)
- `./build.sh --debug` (debug)
- `./build.sh --warnings-as-errors` (strict CI-like compile)

### 4.3 Run

- `./run.sh` (stop existing process, rebuild if stale, launch app bundle)

### 4.4 Test

- `./test.sh`
- In CI it runs `swift test --skip WindowMoverTests`.
- Locally it runs `swift test`; on signal 11 from UI-less environment it reruns with `--skip WindowMoverTests`.

### 4.5 Lint

- `swiftlint --strict` is invoked by pre-commit hook and CI via pre-push.
- `pre-commit run --all-files` to validate local lint and commit-msg rules.

### 4.6 Sanity checks / additional validations

- `./scripts/make_dmg.sh` and `./scripts/test_dmg.sh` are part of CI and required for full PR.

### 4.7 Known environment pitfalls

- Accessibility access must be granted for runtime: Settings → Privacy & Security → Accessibility.
- After rebuild, code-signed binary may require `tccutil reset Accessibility org.nathandrew.mcmac-window` (excuse for failures in local UX tests).
- `WindowMoverTests` may crash with SIG 11 in headless CI or non-GUI sessions; test harness falls back to skip.

## 5) Architecture, behavior, and constraints for changes

- New actions must update:
  1. `WindowAction` enum
  2. `Geometry.computeTargetRect` branch
  3. `HotkeyManager.bindings` mapping
  4. geometry tests in `GeometryTests.swift`
  5. optionally `WindowMoverTests` and `CLAUDE.md` keyboard table.

- Coordinate system rule (must not be violated): work in AX coords; transform once in `axRect(from:primaryScreenHeight:)`.
- Hotkeys: use Carbon `RegisterEventHotKey`; avoid NSEvent global monitor.
- Active app: use `NSWorkspace.shared.frontmostApplication`, not `kAXFocusedApplicationAttribute`.

## 6) Validation and CI replication

- `git fetch origin && git checkout main && git reset --hard origin/main` to align with remote.
- `./build.sh --warnings-as-errors` ensures no warnings.
- `./test.sh` for full suite + fallback path per environment.
- `pre-commit run --all-files` for lint and commit-msg enforcement.
- `./scripts/make_dmg.sh && ./scripts/test_dmg.sh` for packaging and UI/DMG checks.

## 7) Explicit quality guardrails

- Always run tests after code changes (`./test.sh`).
- Always run `./build.sh --warnings-as-errors` before PR.
- Always ensure `pre-commit run --all-files` passes before commit.
- Avoid external dependencies or package additions unless user explicitly approves.
- Commit messages and PR title must follow Conventional Commits (`feat:`, `fix:`, etc.).

## 8) Minimal searching guideline

- Trust this file for workflows, project layout, and key principles.
- Search only if:
  - the onboarding details are outdated for a new major branch state,
  - the requested change is outside snapshots above,
  - or some tool/script fails unexpectedly with no known workaround.

## 9) Required callouts for Copilot cloud agent

- This file is the canonical “do not re-scan everything if not needed” source.
- No task-specific code patterns should be added here; refer to this file for setup and validation.
- If behavior is unclear, re-check `CLAUDE.md`, `CONTRIBUTING.md`, and `ci.yml` in this repo.
## 10) Code review guidelines

When reviewing a pull request, check for the following issues specific to this codebase.

### Coordinate-system correctness (highest priority)
- All AppKit↔AX coordinate conversion must go through `axRect(from:primaryScreenHeight:)` in `Geometry.swift`. A new conversion inlined elsewhere is always a bug.
- In `computeTargetRect`, geometry is in AX coordinates; `vf` is passed as an AppKit rect and converted at the top with `axRect`. Verify new geometry branches use `ax.minX`/`ax.minY`, not `vf.minX`/`vf.minY`.
- Tests in `GeometryTests.swift` assert exact pixel values. If expected values change without an intentional geometry change, that is a sign of a coordinate bug.

### AX API patterns
- Focused window lookup must always use `NSWorkspace.shared.frontmostApplication` — never `kAXFocusedApplicationAttribute` on the system-wide AX element.
- Every `AXUIElementCopyAttributeValue` call must check `== .success` before using the result.
- `as! AXUIElement` and `as! AXValue` for CF types are expected and should carry a `// swiftlint:disable:this force_cast` comment. New force casts on non-CF types are not acceptable.

### Hotkey registration
- Hotkeys must use Carbon `RegisterEventHotKey` in `HotkeyManager.swift`. Any use of `NSEvent.addGlobalMonitorForEvents` is a bug — it silently fails without Input Monitoring permission.
- New bindings must include `keyCode`, `carbonMods`, `action`, `display`, and `group`. The `display` string is shown verbatim in the shortcuts panel.

### New WindowAction checklist
If a new `WindowAction` case is added, verify all five steps are present:
1. Case added to `WindowAction` enum.
2. Geometry branch added to `computeTargetRect` switch (exhaustive — no `default:`).
3. Binding entry added to `HotkeyManager.bindings`.
4. Unit test with exact pixel values added to `GeometryTests.swift`.
5. Keyboard shortcuts table in `CLAUDE.md` updated.

### Swift / safety
- No force unwraps (`!`) on Optional types. Use `guard let`, `if let`, or `??`.
- Prefer `let` over `var`; mutability should be justified.
- New `UserDefaults` keys must be added to the `UDKey` enum in `AppDelegate.swift`, not as inline string literals.
- Use `OSLog` via `Logger(subsystem:category:)` for all new logging — no `print()` statements.

### Tests
- `WindowMoverTests` must use `throw XCTSkip(...)` (not `return`) for AX-dependent paths so CI counts them as skipped rather than passing vacuously.
- Do not lower tolerances in `rectsMatch` or remove assertions to make a failing test pass — fix the geometry.
- `GeometryTests` and `PushThroughTests` are deterministic and must never be skipped.

### CI compliance
- `./build.sh --warnings-as-errors` must pass — no suppressed warnings.
- `swiftlint --strict` must pass — `// swiftlint:disable` is only acceptable for the documented CF force-cast pattern.
- Commit messages must follow Conventional Commits (`feat:`, `fix:`, `refactor:`, etc.).
- No new external dependencies or Xcode project files without explicit approval.