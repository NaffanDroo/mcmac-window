# Velocity-Based Gesture Redesign

**Date:** 2026-04-03
**Branch:** feat/mouse-gesture-desktop-switching

## Problem

The Logitech MX gesture button does not emit mouse button HID events (usage page `0x09`). At every level — raw HID, CGEvent — the firmware translates the button press into an instant `Cmd+Tab` keyDown + keyUp pulse, with no sustained held state. The IOHIDButtonTracker approach relied on catching a HID button-down, but that event never arrives. `gestureButtonHeld` is never set, so `Cmd+Tab` is never suppressed, and the macOS app switcher appears instead of switching spaces.

Diagnostic confirmed firmware sequence (captured via CGEventTap):
```
FLAGS 0x100108   ← flagsChanged: Command modifier goes on (< 5ms before Tab)
KEY DOWN 48      ← Tab, with Command = Cmd+Tab
KEY UP 48
FLAGS 0x100      ← Command modifier off
```

A real keyboard Cmd+Tab has Command held for a perceptible time (>30ms) before Tab is pressed.

## Solution

Replace the IOHIDButtonTracker/held-button model with a **flagsChanged timing discriminator**:

- Record the exact moment Command modifier goes down via `flagsChanged`
- On `keyDown(Tab+Command)`: if Command went down <30ms ago → firmware button → suppress Cmd+Tab and open a movement window
- If Command went down >30ms ago → keyboard → pass through immediately (zero UX impact on keyboard Cmd+Tab)
- Movement window: accumulate `mouseMoved` delta; if threshold reached → switch spaces in that direction; if window expires without threshold → close silently

## What Changes

| Component | Action |
|-----------|--------|
| `IOHIDButtonTracker.swift` | **Delete** |
| `IOHIDButtonTrackerTests.swift` | **Delete** |
| `MouseGestureManager.swift` | Replace logic |
| `MouseGestureManagerTests.swift` | Replace tests |
| `AppDelegate.swift` | Remove `recalibrateGesture()` + recalibrate menu item |
| `Package.swift` | Remove IOKit linker setting |
| `CLAUDE.md` | Update gesture config docs |

## MouseGestureManager — State

Remove:
- `gestureButtonHeld`
- `lastButtonDownTime`
- `tracker: IOHIDButtonTracker`
- `gestureButtonIndex`

Add:
- `lastCmdDownTime: Date?` — when Command modifier last went on; nil when off
- `gestureWindowOpen: Bool` — true while waiting for mouse movement post-suppression
- `gestureWindowOpened: Date?` — when the gesture window was opened (for expiry check)

Keep:
- `accumulatedDelta: CGFloat`
- `lastSwitchTime: Date?`
- `deltaThreshold: CGFloat = 60`
- `cooldown: TimeInterval = 0.5`
- `gestureWindowDuration: TimeInterval = 0.4` (new named constant)
- `cmdTabFirmwareThreshold: TimeInterval = 0.03` (new named constant, 30ms)

## MouseGestureManager — Event Mask

```swift
let eventMask: CGEventMask =
    (1 << CGEventType.flagsChanged.rawValue) |
    (1 << CGEventType.keyDown.rawValue)      |
    (1 << CGEventType.mouseMoved.rawValue)
```

(`flagsChanged` added; rest unchanged from current implementation)

## MouseGestureManager — handleEvent Logic

```
flagsChanged:
  if event.flags.contains(.maskCommand) && lastCmdDownTime == nil:
    lastCmdDownTime = Date()
  else if !event.flags.contains(.maskCommand):
    lastCmdDownTime = nil
  return passthrough

keyDown (keyCode == 48, flags contain .maskCommand):
  if lastCmdDownTime == nil: return passthrough         // no flagsChanged seen (shouldn't happen)
  gap = Date().timeIntervalSince(lastCmdDownTime!)
  if gap > cmdTabFirmwareThreshold: return passthrough  // keyboard Cmd+Tab, don't touch it
  // firmware button — suppress and open gesture window
  if !gestureWindowOpen:
    gestureWindowOpen = true
    gestureWindowOpened = Date()
    accumulatedDelta = 0
  return nil   // suppress Cmd+Tab

mouseMoved:
  guard gestureWindowOpen else: return passthrough
  // check expiry
  if let opened = gestureWindowOpened,
     Date().timeIntervalSince(opened) > gestureWindowDuration:
    gestureWindowOpen = false
    gestureWindowOpened = nil
    accumulatedDelta = 0
    return passthrough
  // check denylist
  guard let bundleID = frontmostBundleID(),
        !gestureDisabledBundleIDs().contains(bundleID) else: return passthrough
  guard !isSnappingPaused() else: return passthrough
  // accumulate
  accumulatedDelta += dx
  guard abs(accumulatedDelta) >= deltaThreshold else: return passthrough
  // cooldown
  if let last = lastSwitchTime, Date().timeIntervalSince(last) < cooldown:
    accumulatedDelta = 0
    return passthrough
  // fire
  let direction: GestureDirection = accumulatedDelta > 0 ? .right : .left
  switchAction(direction)
  accumulatedDelta = 0
  lastSwitchTime = Date()
  gestureWindowOpen = false
  gestureWindowOpened = nil
  return passthrough
```

## Testing

All CGEvent-based tests use `XCTSkip` if `CGEventSource` creation fails (same pattern as existing tests).

| Test | Behaviour verified |
|------|--------------------|
| `testFirmwareCmdTabSuppressed` | flagsChanged sets `lastCmdDownTime`; keyDown <30ms later → nil returned, `gestureWindowOpen == true` |
| `testKeyboardCmdTabPassesThrough` | `lastCmdDownTime` set to `Date(timeIntervalSinceNow: -0.1)`; keyDown → non-nil returned, `gestureWindowOpen == false` |
| `testGestureRight` | `gestureWindowOpen = true`, `handleMouseMoved(dx: 60)` → `firedDirections == [.right]`, window closed |
| `testGestureLeft` | `gestureWindowOpen = true`, `handleMouseMoved(dx: -60)` → `firedDirections == [.left]` |
| `testWindowExpiryNoSwitch` | `gestureWindowOpen = true`, `gestureWindowOpened = Date(timeIntervalSinceNow: -0.5)`, `handleMouseMoved(dx: 60)` → no switch, window closed |
| `testNoSwitchWhenWindowClosed` | `gestureWindowOpen = false`, `handleMouseMoved(dx: 60)` → no switch |
| `testDenylistBlocksSwitch` | app in denylist, `gestureWindowOpen = true`, threshold reached → no switch |
| `testSnappingPausedBlocksSwitch` | `isSnappingPaused = { true }`, window open, threshold → no switch |
| `testCooldownBlocksSwitch` | `lastSwitchTime = Date()`, window open, threshold → no switch |
| `testSwitchFiresAfterCooldownExpires` | `lastSwitchTime = Date(timeIntervalSinceNow: -0.6)`, window open, threshold → switch fires |
| `testDeltaResetsAfterSwitch` | after switch fires, `accumulatedDelta == 0`, `gestureWindowOpen == false` |

## AppDelegate Changes

Remove:
- `private var recalibrateMenuItem: NSMenuItem?`
- `recalibrateGesture()` method
- The "Re-calibrate Gesture Button" menu item from `setupStatusItem`
- `recalibrateMenuItem?.isHidden = paused` from `updateGestureMenuItem`

Keep everything else (denylist model, "Disable/Enable Mouse Gesture for [App]" toggle).

## Package.swift

Remove `.linkedFramework("IOKit")` from `McMacWindowCore` linker settings.

## CLAUDE.md

Update gesture configuration section — remove `gestureButtonUsagePage` and `gestureButtonUsageID` keys (calibration is gone). Update description to reflect velocity-based approach.

## Constants

| Constant | Value | Rationale |
|----------|-------|-----------|
| `cmdTabFirmwareThreshold` | 30ms | Firmware fires flagsChanged→keyDown in <5ms; humans physically cannot press Cmd+Tab this fast |
| `gestureWindowDuration` | 400ms | Long enough to move comfortably, short enough to not feel laggy |
| `deltaThreshold` | 60pt | Unchanged — same as before |
| `cooldown` | 0.5s | Unchanged |
