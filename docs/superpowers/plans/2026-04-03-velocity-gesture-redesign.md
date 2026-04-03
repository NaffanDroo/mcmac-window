# Velocity-Based Gesture Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken IOHIDButtonTracker approach with a `flagsChanged`-timing discriminator so the Logitech gesture button reliably switches Mission Control Spaces without triggering the macOS app switcher.

**Architecture:** `flagsChanged` events record when Command modifier goes down. On `keyDown(Tab+Cmd)`, if Command went down <30ms ago it's the firmware button — suppress it and open a 400ms movement window. Mouse movement during the window switches spaces directionally. If the window expires unused, it closes silently. Keyboard Cmd+Tab (Command held >30ms before Tab) always passes through with zero delay.

**Tech Stack:** Swift, CoreGraphics (CGEventTap, CGEventType.flagsChanged), XCTest

---

## File Map

| Action | File |
|--------|------|
| Delete | `Sources/McMacWindowCore/IOHIDButtonTracker.swift` |
| Delete | `Tests/McMacWindowTests/IOHIDButtonTrackerTests.swift` |
| Modify | `Package.swift` — remove IOKit |
| Rewrite | `Sources/McMacWindowCore/MouseGestureManager.swift` |
| Rewrite | `Tests/McMacWindowTests/MouseGestureManagerTests.swift` |
| Modify | `Sources/McMacWindowCore/AppDelegate.swift` — remove recalibrate |
| Modify | `CLAUDE.md` — update gesture config docs |

---

## Task 1: Remove IOHIDButtonTracker and IOKit

**Files:**
- Delete: `Sources/McMacWindowCore/IOHIDButtonTracker.swift`
- Delete: `Tests/McMacWindowTests/IOHIDButtonTrackerTests.swift`
- Modify: `Package.swift`

- [ ] **Step 1: Delete the two files**

```bash
rm Sources/McMacWindowCore/IOHIDButtonTracker.swift
rm Tests/McMacWindowTests/IOHIDButtonTrackerTests.swift
```

- [ ] **Step 2: Remove IOKit from Package.swift**

In `Package.swift`, remove `.linkedFramework("IOKit")` so the linkerSettings block reads:

```swift
linkerSettings: [
    .linkedFramework("AppKit"),
    .linkedFramework("ApplicationServices"),
    .linkedFramework("Carbon"),
]
```

- [ ] **Step 3: Verify build fails (MouseGestureManager still references IOHIDButtonTracker)**

```bash
./build.sh 2>&1 | grep -i "error:" | head -10
```

Expected: errors about `IOHIDButtonTracker` not found — confirms the deletion is wired correctly and Task 2 is needed.

- [ ] **Step 4: Commit**

```bash
git add Package.swift
git rm Sources/McMacWindowCore/IOHIDButtonTracker.swift
git rm Tests/McMacWindowTests/IOHIDButtonTrackerTests.swift
git commit -m "chore: remove IOHIDButtonTracker and IOKit dependency"
```

---

## Task 2: Write new MouseGestureManagerTests (failing)

**Files:**
- Rewrite: `Tests/McMacWindowTests/MouseGestureManagerTests.swift`

Replace the entire file. These tests will compile only after Task 3 reworks `MouseGestureManager`.

- [ ] **Step 1: Replace MouseGestureManagerTests.swift**

```swift
import XCTest
import CoreGraphics
import ApplicationServices
@testable import McMacWindowCore

final class MouseGestureManagerTests: XCTestCase {

    var manager: MouseGestureManager!
    var firedDirections: [GestureDirection] = []

    override func setUp() {
        super.setUp()
        manager = MouseGestureManager()
        manager.switchAction = { [weak self] dir in self?.firedDirections.append(dir) }
        manager.frontmostBundleID = { "com.test.app" }
        manager.isSnappingPaused = { false }
        UserDefaults.standard.removeObject(forKey: "gestureDisabledBundleIDs")
        firedDirections = []
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "gestureDisabledBundleIDs")
        super.tearDown()
    }

    // MARK: - flagsChanged discrimination

    func testFirmwareCmdTabSuppressed() throws {
        guard let src = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: src, virtualKey: 48, keyDown: true) else {
            throw XCTSkip("Cannot create CGEvent in test environment")
        }
        event.flags = .maskCommand
        // Simulate flagsChanged <30ms ago
        manager.lastCmdDownTime = Date()
        let result = manager.handleEvent(type: .keyDown, event: event)
        XCTAssertNil(result, "Firmware Cmd+Tab should be suppressed")
        XCTAssertTrue(manager.gestureWindowOpen, "Gesture window should open after suppression")
    }

    func testKeyboardCmdTabPassesThrough() throws {
        guard let src = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: src, virtualKey: 48, keyDown: true) else {
            throw XCTSkip("Cannot create CGEvent in test environment")
        }
        event.flags = .maskCommand
        // Simulate Command held for 100ms (keyboard user)
        manager.lastCmdDownTime = Date(timeIntervalSinceNow: -0.1)
        let result = manager.handleEvent(type: .keyDown, event: event)
        XCTAssertNotNil(result, "Keyboard Cmd+Tab should pass through")
        XCTAssertFalse(manager.gestureWindowOpen, "Gesture window should not open for keyboard Cmd+Tab")
    }

    func testFlagsChangedSetsCmdDownTime() throws {
        guard let src = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) else {
            throw XCTSkip("Cannot create CGEvent in test environment")
        }
        event.flags = .maskCommand
        XCTAssertNil(manager.lastCmdDownTime)
        _ = manager.handleEvent(type: .flagsChanged, event: event)
        XCTAssertNotNil(manager.lastCmdDownTime)
    }

    func testFlagsChangedClearsCmdDownTimeOnRelease() throws {
        guard let src = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) else {
            throw XCTSkip("Cannot create CGEvent in test environment")
        }
        event.flags = [] // no modifiers = Command released
        manager.lastCmdDownTime = Date()
        _ = manager.handleEvent(type: .flagsChanged, event: event)
        XCTAssertNil(manager.lastCmdDownTime)
    }

    func testNonTabKeyPassesThroughEvenWithRecentCmd() throws {
        guard let src = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true) else {
            throw XCTSkip("Cannot create CGEvent in test environment")
        }
        event.flags = .maskCommand
        manager.lastCmdDownTime = Date()
        let result = manager.handleEvent(type: .keyDown, event: event)
        XCTAssertNotNil(result, "Non-Tab key should pass through")
        XCTAssertFalse(manager.gestureWindowOpen)
    }

    func testNoCmdDownTimePassesThrough() throws {
        guard let src = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: src, virtualKey: 48, keyDown: true) else {
            throw XCTSkip("Cannot create CGEvent in test environment")
        }
        event.flags = .maskCommand
        manager.lastCmdDownTime = nil
        let result = manager.handleEvent(type: .keyDown, event: event)
        XCTAssertNotNil(result, "Cmd+Tab with no flagsChanged record passes through")
    }

    // MARK: - Gesture window + movement

    func testGestureRight() {
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
        XCTAssertFalse(manager.gestureWindowOpen)
    }

    func testGestureLeft() {
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: -60)
        XCTAssertEqual(firedDirections, [.left])
    }

    func testDeltaAccumulates() {
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 30)
        manager.handleMouseMoved(dx: 30)
        XCTAssertEqual(firedDirections, [.right])
    }

    func testBelowThresholdNoSwitch() {
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 59)
        XCTAssertTrue(firedDirections.isEmpty)
    }

    func testDeltaResetsAfterSwitch() {
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(manager.accumulatedDelta, 0)
        XCTAssertFalse(manager.gestureWindowOpen)
    }

    func testWindowExpiryNoSwitch() {
        manager.gestureWindowOpen = true
        // Window opened 500ms ago — past the 400ms expiry
        manager.gestureWindowOpened = Date(timeIntervalSinceNow: -0.5)
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty, "Expired window should not fire switch")
        XCTAssertFalse(manager.gestureWindowOpen, "Window should be closed after expiry")
    }

    func testMovementIgnoredWhenWindowClosed() {
        manager.gestureWindowOpen = false
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
        XCTAssertEqual(manager.accumulatedDelta, 0)
    }

    // MARK: - Denylist gating

    func testAppInDenylistSuppressesSwitch() {
        UserDefaults.standard.set(["com.test.app"], forKey: "gestureDisabledBundleIDs")
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
    }

    func testAppNotInDenylistAllowsSwitch() {
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
    }

    func testUnrelatedAppInDenylistDoesNotSuppressSwitch() {
        UserDefaults.standard.set(["com.other.app"], forKey: "gestureDisabledBundleIDs")
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
    }

    func testNoFrontmostAppSuppressesSwitch() {
        manager.frontmostBundleID = { nil }
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
    }

    // MARK: - Pause gating

    func testSnappingPausedSuppressesSwitch() {
        manager.isSnappingPaused = { true }
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
    }

    // MARK: - Cooldown

    func testCooldownSuppressesImmediateRepeat() {
        manager.lastSwitchTime = Date()
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
        XCTAssertEqual(manager.accumulatedDelta, 0)
    }

    func testSwitchFiresAfterCooldownExpires() {
        manager.lastSwitchTime = Date(timeIntervalSinceNow: -0.6)
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
    }

    // MARK: - CGEventTap lifecycle (requires Accessibility permission)

    func testStartCreatesTap() throws {
        guard AXIsProcessTrustedWithOptions(nil) else {
            throw XCTSkip("Accessibility permission not granted — skipping CGEventTap test")
        }
        let mgr = MouseGestureManager()
        mgr.start()
        XCTAssertEqual(mgr.eventTapIsEnabled, true)
        mgr.stop()
        XCTAssertNil(mgr.eventTapIsEnabled)
    }

    func testDoubleStartIsNoop() throws {
        guard AXIsProcessTrustedWithOptions(nil) else {
            throw XCTSkip("Accessibility permission not granted — skipping CGEventTap test")
        }
        let mgr = MouseGestureManager()
        mgr.start()
        let tapAfterFirst = mgr.eventTapIsEnabled
        mgr.start()
        XCTAssertEqual(mgr.eventTapIsEnabled, tapAfterFirst)
        mgr.stop()
    }
}
```

- [ ] **Step 2: Verify tests fail to compile**

```bash
./test.sh 2>&1 | grep "error:" | head -10
```

Expected: errors about `lastCmdDownTime`, `gestureWindowOpen`, `gestureWindowOpened` not found, and `tracker` / `gestureButtonHeld` / `handleMouseMoved` signature mismatches. This confirms tests drive the implementation.

---

## Task 3: Rewrite MouseGestureManager

**Files:**
- Rewrite: `Sources/McMacWindowCore/MouseGestureManager.swift`

- [ ] **Step 1: Replace MouseGestureManager.swift entirely**

```swift
import AppKit
import CoreGraphics
import OSLog

private let logger = Logger(subsystem: "org.nathandrew.mcmac-window", category: "MouseGestureManager")

// Time gap between flagsChanged (Command on) and keyDown(Tab) that distinguishes
// firmware button (<30ms) from a human keyboard press (>30ms).
private let cmdTabFirmwareThreshold: TimeInterval = 0.03

// How long to wait for mouse movement after suppressing a firmware Cmd+Tab.
private let gestureWindowDuration: TimeInterval = 0.4

public enum GestureDirection {
    case left, right
}

public class MouseGestureManager {

    // MARK: - Singleton
    public static let shared = MouseGestureManager()

    // MARK: - Injectable dependencies (overridden in tests)
    var switchAction: (GestureDirection) -> Void = { MouseGestureManager.postSpaceSwitch(direction: $0) }
    var frontmostBundleID: () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
    var isSnappingPaused: () -> Bool = { UserDefaults.standard.bool(forKey: "snappingPaused") }

    // MARK: - Configuration
    var deltaThreshold: CGFloat = 60
    var cooldown: TimeInterval = 0.5

    // MARK: - State
    // lastCmdDownTime: set by flagsChanged when Command goes on; cleared when it goes off.
    var lastCmdDownTime: Date?
    // gestureWindowOpen: true while waiting for directional mouse movement post-button-press.
    var gestureWindowOpen = false
    var gestureWindowOpened: Date?
    private(set) var accumulatedDelta: CGFloat = 0
    var lastSwitchTime: Date?

    // MARK: - Event tap
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {}

    deinit {
        stop()
    }

    // MARK: - Mouse moved

    func handleMouseMoved(dx: CGFloat) {
        guard gestureWindowOpen else { return }

        // Check expiry first — always close if window has lapsed.
        if let opened = gestureWindowOpened,
           Date().timeIntervalSince(opened) > gestureWindowDuration {
            gestureWindowOpen = false
            gestureWindowOpened = nil
            accumulatedDelta = 0
            logger.debug("gesture window expired without threshold")
            return
        }

        guard let bundleID = frontmostBundleID(),
              !gestureDisabledBundleIDs().contains(bundleID) else { return }
        guard !isSnappingPaused() else { return }

        accumulatedDelta += dx
        guard abs(accumulatedDelta) >= deltaThreshold else { return }

        if let last = lastSwitchTime, Date().timeIntervalSince(last) < cooldown {
            accumulatedDelta = 0
            return
        }

        let direction: GestureDirection = accumulatedDelta > 0 ? .right : .left
        logger.debug("gesture fired: \(direction == .right ? "right" : "left", privacy: .public)")
        switchAction(direction)
        accumulatedDelta = 0
        lastSwitchTime = Date()
        gestureWindowOpen = false
        gestureWindowOpened = nil
    }

    private func gestureDisabledBundleIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: "gestureDisabledBundleIDs") ?? []
    }

    // MARK: - Event handling (internal for tests)

    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            if event.flags.contains(.maskCommand) {
                if lastCmdDownTime == nil {
                    lastCmdDownTime = Date()
                }
            } else {
                lastCmdDownTime = nil
            }

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let hasCmd  = event.flags.contains(.maskCommand)
            guard keyCode == 48 && hasCmd else { break }
            guard let cmdDown = lastCmdDownTime else { break }
            let gap = Date().timeIntervalSince(cmdDown)
            guard gap < cmdTabFirmwareThreshold else { break }
            // Firmware button: suppress and open gesture window.
            if !gestureWindowOpen {
                gestureWindowOpen = true
                gestureWindowOpened = Date()
                accumulatedDelta = 0
                logger.debug("firmware Cmd+Tab suppressed, gesture window opened")
            }
            return nil

        case .mouseMoved:
            handleMouseMoved(dx: CGFloat(event.getDoubleValueField(.mouseEventDeltaX)))

        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Space switching

    static func postSpaceSwitch(direction: GestureDirection) {
        let keyCode: CGKeyCode = direction == .right ? 124 : 123
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = .maskControl
        up.flags   = .maskControl
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        logger.debug("posted space switch: \(direction == .right ? "right" : "left", privacy: .public)")
    }

    // MARK: - Lifecycle

    public func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)      |
            (1 << CGEventType.mouseMoved.rawValue)

        // passUnretained is safe because deinit calls stop(), closing the tap
        // before self is deallocated. Do not remove the deinit.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let mgr = Unmanaged<MouseGestureManager>.fromOpaque(userInfo).takeUnretainedValue()
                return mgr.handleEvent(type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            logger.error("CGEventTap creation failed — Accessibility permission likely not granted")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.info("MouseGestureManager started")
    }

    public func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        logger.info("MouseGestureManager stopped")
    }

    /// Exposed for testing only — returns whether the tap exists and is enabled.
    var eventTapIsEnabled: Bool? {
        guard let tap = eventTap else { return nil }
        return CGEvent.tapIsEnabled(tap: tap)
    }
}
```

- [ ] **Step 2: Run tests**

```bash
./test.sh
```

Expected: all tests pass or skip. Zero failures. The `IOHIDButtonTrackerTests` are gone; `MouseGestureManagerTests` all pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/McMacWindowCore/MouseGestureManager.swift \
        Tests/McMacWindowTests/MouseGestureManagerTests.swift
git commit -m "feat: replace IOHIDButtonTracker with flagsChanged timing discriminator"
git push
```

---

## Task 4: Clean up AppDelegate

**Files:**
- Modify: `Sources/McMacWindowCore/AppDelegate.swift`

Remove the recalibrate menu item — calibration no longer exists.

- [ ] **Step 1: Remove the recalibrateMenuItem property**

Find and remove this line (around line 24):
```swift
private var recalibrateMenuItem: NSMenuItem?
```

- [ ] **Step 2: Remove the recalibrate menu item from setupStatusItem**

Find and remove these lines (the recalibrate item added between gestureItem and the separator):
```swift
let recalibrateItem = NSMenuItem(title: "Re-calibrate Gesture Button",
                                 action: #selector(recalibrateGesture), keyEquivalent: "")
recalibrateItem.target = self
menu.addItem(recalibrateItem)
recalibrateMenuItem = recalibrateItem
```

- [ ] **Step 3: Remove the recalibrateGesture method**

Find and remove:
```swift
@objc private func recalibrateGesture() {
    MouseGestureManager.shared.tracker.resetCalibration()
}
```

- [ ] **Step 4: Remove recalibrateMenuItem from updateGestureMenuItem**

Find and remove this line in `updateGestureMenuItem()`:
```swift
recalibrateMenuItem?.isHidden = paused
```

- [ ] **Step 5: Build and test**

```bash
./build.sh && ./test.sh
```

Expected: clean build, all tests pass or skip.

- [ ] **Step 6: Commit**

```bash
git add Sources/McMacWindowCore/AppDelegate.swift
git commit -m "chore: remove recalibrate menu item (calibration no longer needed)"
git push
```

---

## Task 5: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the gesture configuration section**

Find:
```
Configuration (via `UserDefaults`):
- `gestureButtonUsagePage` (Int) — HID usage page of the gesture button; stored automatically on first press (calibration)
- `gestureButtonUsageID` (Int) — HID usage ID of the gesture button; stored automatically on first press (calibration)
- `gestureDisabledBundleIDs` ([String]) — the per-app denylist managed by the menu
```

Replace with:
```
Configuration (via `UserDefaults`):
- `gestureDisabledBundleIDs` ([String]) — the per-app denylist managed by the menu
```

- [ ] **Step 2: Update the feature description**

Find:
```
The feature is **opt-out per application**. Use "Disable Mouse Gesture for [App]" in the menu bar to add or remove the frontmost app from the denylist. Use "Re-calibrate Gesture Button" to re-learn the button's HID usage (needed if the button mapping changes or on first launch). The gesture is suppressed when Snapping is paused.
```

Replace with:
```
The feature is **opt-out per application**. Use "Disable Mouse Gesture for [App]" in the menu bar to add or remove the frontmost app from the denylist. The gesture is suppressed when Snapping is paused.

The gesture works by detecting the Logitech firmware's `Cmd+Tab` pulse: when Command goes down <30ms before Tab, it's the hardware button (not keyboard). The `Cmd+Tab` is suppressed and a 400ms window opens — move the mouse left or right to switch spaces. If the window expires without movement, nothing happens.
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for velocity-based gesture redesign"
git push
```
