# IOHIDManager Gesture Button Rework

**Date:** 2026-03-31
**Branch:** feat/mouse-gesture-desktop-switching

## Problem

The current `MouseGestureManager` listens for `otherMouseDown`/`otherMouseDragged` CGEvents to detect when the Logitech MX gesture button is held and the mouse is dragged. This does not work because the gesture button never generates mouse button events — the firmware sends an instant `Cmd+Tab` keyboard event (keyCode 48, flags `maskCommand`) at the HID level instead, bypassing the mouse event system entirely. The button press and release happen as an immediate key-down/key-up pair regardless of how long the button is physically held.

## Goals

1. Detect the physical press and release of the Logitech gesture button accurately.
2. Suppress the `Cmd+Tab` keyboard event the firmware generates, so the macOS app switcher does not open.
3. Track mouse movement while the button is physically held and switch Mission Control Spaces on threshold.
4. Leave keyboard `Cmd+Tab` (from the actual keyboard) completely unaffected.
5. Change the per-app model from opt-in (allowlist) to opt-out (denylist) — gesture is active for all apps by default.

## Non-Goals

- Supporting non-Logitech mice.
- Re-posting `Cmd+Tab` on a tap with no movement (user confirmed: button is for space-switching only).
- Any change to the space-switch mechanic itself (`postSpaceSwitch` is unchanged).

## Architecture

Three targeted changes to the existing codebase:

```
IOHIDButtonTracker   (new)
       │  onButtonDown / onButtonUp
       ▼
MouseGestureManager  (modified)
  ├── IOHIDButtonTracker drives gestureButtonHeld
  ├── CGEventTap: intercepting, suppresses Cmd+Tab when button held
  ├── Event mask: mouseMoved + keyDown (replaces otherMouseDragged etc.)
  └── Opt-out denylist replaces opt-in allowlist
AppDelegate          (modified)
  └── Menu item inverted + "Re-calibrate" item added
Package.swift        (modified)
  └── IOKit added to McMacWindowCore linker settings
```

## Component: `IOHIDButtonTracker`

**File:** `Sources/McMacWindowCore/IOHIDButtonTracker.swift`

A thin wrapper around `IOHIDManager`. Its only responsibilities are device matching, usage discovery, and firing callbacks. It has no knowledge of gestures or spaces.

### Public interface

```swift
class IOHIDButtonTracker {
    var onButtonDown: () -> Void
    var onButtonUp:   () -> Void

    func start()            // creates IOHIDManager, schedules on current run loop
    func stop()             // closes manager, cleans up
    func resetCalibration() // clears stored HID usage from UserDefaults
}
```

### Device matching

Matches devices with `kIOHIDVendorIDKey = 0x046D` (Logitech). Registers an input-value callback for all HID elements with usage page `kHIDPage_Button` (0x0009).

### HID usage discovery (calibration mode)

The exact HID usage ID for the gesture button varies by MX model. On first button-down event received from any matched device, the tracker records `(usagePage, usageID)` into `UserDefaults` under keys `gestureButtonUsagePage` and `gestureButtonUsageID`, then switches to normal mode. In normal mode, only events matching the stored usage fire `onButtonDown`/`onButtonUp`. `resetCalibration()` deletes both keys and returns to calibration mode.

This means: on first launch, the user presses the gesture button once to calibrate. All subsequent uses work automatically.

### Run loop scheduling

`IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)` — scheduled on the **main run loop**, the same run loop as the CGEventTap. This serialises callbacks so `onButtonDown` fires before the synthesised `Cmd+Tab` keyboard event reaches the tap.

## Component: `MouseGestureManager` (changes)

### 1. Button state source

`IOHIDButtonTracker` is created and owned by `MouseGestureManager`. Its callbacks replace `handleMouseDown`/`handleMouseUp`:

```swift
tracker.onButtonDown = { [weak self] in
    self?.gestureButtonHeld = true
    self?.lastButtonDownTime = Date()
}
tracker.onButtonUp = { [weak self] in
    self?.gestureButtonHeld = false
    self?.accumulatedDelta = 0
}
```

`handleMouseDown` and `handleMouseUp` are removed.

### 2. Event tap mode

Changed from `.listenOnly` to `.defaultTap`. The callback returns `nil` to consume an event or `Unmanaged.passUnretained(event)` to pass it through.

### 3. Event mask

```swift
let eventMask: CGEventMask =
    (1 << CGEventType.mouseMoved.rawValue) |
    (1 << CGEventType.keyDown.rawValue)
```

- `otherMouseDown`, `otherMouseUp`, `otherMouseDragged` removed — `IOHIDButtonTracker` handles button state.
- `mouseMoved` replaces `otherMouseDragged` — since the gesture button doesn't register as a mouse button, movement during the gesture appears as `mouseMoved`, not `otherMouseDragged`.
- `keyDown` added — to intercept and suppress `Cmd+Tab`.

### 4. Cmd+Tab suppression

In the event callback, for `keyDown` events:

```swift
case .keyDown:
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let isTab   = keyCode == 48
    let hasCmd  = event.flags.contains(.maskCommand)
    let withinWindow = lastButtonDownTime.map {
        Date().timeIntervalSince($0) < 0.05
    } ?? false
    if isTab && hasCmd && (gestureButtonHeld || withinWindow) {
        return nil   // suppress — firmware-generated Cmd+Tab
    }
    return Unmanaged.passUnretained(event)  // pass through keyboard Cmd+Tab
```

The 50ms window guards against any run-loop ordering edge case where the CGEvent tap fires before `onButtonDown`.

### 5. Opt-out model

`gestureEnabledBundleIDs` → `gestureDisabledBundleIDs`. Logic in `handleMouseMoved` inverts:

```swift
// Before (opt-in):
guard gestureEnabledBundleIDs().contains(bundleID) else { return }

// After (opt-out):
guard !gestureDisabledBundleIDs().contains(bundleID) else { return }
```

`UserDefaults` key changes from `"gestureEnabledBundleIDs"` to `"gestureDisabledBundleIDs"`.

## Component: `AppDelegate` (changes)

### Menu item logic

The gesture toggle item inverts:

- Default label: **"Disable Mouse Gesture for [App]"** (gesture is on)
- When current app is in denylist: **"Enable Mouse Gesture for [App]"**

Reads/writes `gestureDisabledBundleIDs`.

### New menu item

**"Re-calibrate Gesture Button"** — calls `MouseGestureManager.shared.tracker.resetCalibration()`. Appears below the toggle item in the gesture section.

## `Package.swift` change

Add `IOKit` to `McMacWindowCore` linker settings:

```swift
.linkedFramework("IOKit"),
```

## Calibration UX flow

1. User launches app for the first time (or after re-calibration).
2. Gesture button has no stored HID usage — `IOHIDButtonTracker` is in calibration mode.
3. User presses the gesture button once. `IOHIDButtonTracker` records the usage and switches to normal mode. The `Cmd+Tab` from this first press is still suppressed (the calibration fires synchronously before the keyboard event).
4. All subsequent presses work as gestures.

No explicit UI prompt is needed for initial calibration — the button is pressed naturally when the user first tries to use the gesture.

## Testing

`IOHIDButtonTracker` requires real hardware and has no unit tests. It is kept intentionally thin to minimise untested surface.

`MouseGestureManager` uses injectable dependencies throughout. Tests drive button state by calling `tracker.onButtonDown()` / `tracker.onButtonUp()` directly on a mock tracker (or by setting `gestureButtonHeld` directly).

### New / updated test cases

| Test | File |
|------|------|
| Button down + mouse move ≥ threshold → `switchAction` fires with correct direction | `MouseGestureManagerTests` |
| Button down + mouse move < threshold → no switch | `MouseGestureManagerTests` |
| Button not held + `keyDown` keyCode 48 + Command → event passes through | `MouseGestureManagerTests` |
| Button held + `keyDown` keyCode 48 + Command → event suppressed (returns nil) | `MouseGestureManagerTests` |
| Bundle ID in denylist + button down + move → no switch | `MouseGestureManagerTests` |
| Bundle ID not in denylist + button down + move → switch fires | `MouseGestureManagerTests` |
| `IOHIDButtonTracker` calibration: first event stores usage, subsequent non-matching events ignored | `IOHIDButtonTrackerTests` (skipped in CI — requires hardware) |

Existing tests that call `handleMouseDown`/`handleMouseUp` are updated to call `gestureButtonHeld = true/false` directly.

## Migration

`gestureEnabledBundleIDs` is not migrated. Users who had opted specific apps in will find the gesture now active everywhere by default, and can opt out the apps they don't want. This is acceptable given the feature is new and the allowlist was empty by default anyway.
