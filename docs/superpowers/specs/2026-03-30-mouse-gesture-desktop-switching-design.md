# Mouse Gesture Desktop Switching — Design Spec

**Date:** 2026-03-30
**Issue:** NaffanDroo/mcmac-window#72

## Summary

Add support for the Logitech MX mouse gesture button (the button under the thumb) combined with left/right mouse movement to switch macOS desktops (Mission Control Spaces). The feature is opt-in per-application, mirroring the existing per-app ignore list pattern.

## Behaviour

- Hold the gesture button + move mouse right → switch to next Space (`^→`)
- Hold the gesture button + move mouse left → switch to previous Space (`^←`)
- The frontmost window is not moved — only the active desktop changes
- Only fires when the frontmost app is in the gesture allowlist
- Respects the global "Pause Snapping" state (gesture is suppressed when paused)

## Architecture

One new source file: `Sources/McMacWindowCore/MouseGestureManager.swift`

```
AppDelegate
  └─ MouseGestureManager.shared.start()
       ├─ CGEventTap  (otherMouseDown / otherMouseUp / mouseMoved)
       ├─ gesture button held? → accumulate horizontal delta
       └─ |delta| ≥ threshold → postSpaceSwitch(direction) → reset delta + cooldown
```

Desktop switching is implemented by posting a `CGEvent` for `^→` / `^←` via `CGEventPost(nil, ...)`. No private APIs.

## Components

### `MouseGestureManager` (new file)

**State:**
- `gestureButtonHeld: Bool` — set on `otherMouseDown` matching the configured button index; cleared on `otherMouseUp`
- `accumulatedDelta: CGFloat` — horizontal mouse delta summed while `gestureButtonHeld`; reset to zero after a switch fires or the button is released
- `lastSwitchTime: Date?` — used to enforce the cooldown

**Configuration (UserDefaults):**
- `gestureButtonIndex: Int` — raw CGEvent button number for the MX gesture button. Default: `3`. Stored in UserDefaults so it can be overridden without a rebuild.
- `gestureEnabledBundleIDs: [String]` — allowlist of bundle IDs for which the gesture is active

**Constants:**
- `deltaThreshold: CGFloat = 60` — minimum horizontal movement (px) to trigger a switch
- `cooldown: TimeInterval = 0.5` — minimum seconds between consecutive switches

**Trigger logic (pseudocode):**
```
on otherMouseDown(button: N):
    if N == gestureButtonIndex: gestureButtonHeld = true

on otherMouseUp(button: N):
    if N == gestureButtonIndex:
        gestureButtonHeld = false
        accumulatedDelta = 0

on mouseMoved(dx):
    guard gestureButtonHeld else return
    guard frontmostApp in gestureEnabledBundleIDs else return
    guard !snappingPaused else return
    accumulatedDelta += dx
    if abs(accumulatedDelta) >= deltaThreshold:
        guard now - lastSwitchTime > cooldown else return
        postSpaceSwitch(direction: accumulatedDelta > 0 ? .right : .left)
        accumulatedDelta = 0
        lastSwitchTime = now
```

**Space switch implementation:**
```swift
func postSpaceSwitch(direction: Direction) {
    let keyCode: CGKeyCode = direction == .right ? 124 : 123  // right/left arrow
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
    let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
    down?.flags = .maskControl
    up?.flags   = .maskControl
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}
```

**Testability:** The `postSpaceSwitch` function is injected as a closure (`var switchAction: (Direction) -> Void`) so tests can pass a spy without needing real hardware or posting real events.

### `AppDelegate` changes

**New UserDefaults key:** `gestureEnabledBundleIDs: [String]`

**New menu items** (inserted after the existing ignore section, before the Shortcuts separator):
- `"Enable Mouse Gesture for [App]"` / `"✓ Mouse Gesture for [App]"` — toggles the frontmost app in/out of `gestureEnabledBundleIDs`
- Greyed out when snapping is paused (same behaviour as the ignore items)
- Refreshed in `menuWillOpen` alongside the other dynamic items

**Launch:** `MouseGestureManager.shared.start()` called in `applicationDidFinishLaunching`, alongside `HotkeyManager.shared.register()`.

## Tests (`MouseGestureManagerTests.swift`)

| Test | What it verifies |
|------|-----------------|
| `testDeltaBelowThreshold` | No switch fires when delta < 60px |
| `testDeltaRightTrigger` | Switch fires right when delta ≥ +60px |
| `testDeltaLeftTrigger` | Switch fires left when delta ≤ −60px |
| `testDeltaResetsAfterTrigger` | Delta resets to 0 after a switch |
| `testButtonReleasedResetsDelta` | Accumulated delta discarded on button up |
| `testCooldownSuppressesRapidFire` | Second trigger within 500ms is suppressed |
| `testAppNotInAllowlist` | No switch fires when app not in list |
| `testAppInAllowlist` | Switch fires when app is in list |
| `testSnappingPausedSuppressesGesture` | No switch fires when snapping is paused |

The `CGEventTap` installation block itself is guarded with `XCTSkip` in headless CI (no AX permission), consistent with `WindowMoverTests`.

## Files Changed

| File | Change |
|------|--------|
| `Sources/McMacWindowCore/MouseGestureManager.swift` | New |
| `Sources/McMacWindowCore/AppDelegate.swift` | Add menu items + launch call |
| `Tests/McMacWindowTests/MouseGestureManagerTests.swift` | New |

## Out of Scope

- Moving the frontmost window to the new Space (just switches desktop)
- Support for other mouse brands or button configurations beyond the default index
- A settings UI for changing the button index (UserDefaults override is sufficient for now)
- Horizontal scroll wheel tilt as an alternative trigger
