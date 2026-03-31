# MouseGestureManager IOHIDManager Rework — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken `otherMouseDown`/`otherMouseDragged` CGEventTap approach with IOHIDManager-based physical button detection, so the Logitech gesture button works without Logi Options installed.

**Architecture:** `IOHIDButtonTracker` wraps `IOHIDManager` to detect physical button press/release from the Logitech device before the OS translates it into `Cmd+Tab`. `MouseGestureManager` uses these callbacks to set `gestureButtonHeld` and a non-passive `CGEventTap` suppresses the `Cmd+Tab` keyboard event when the button is physically down. Gesture model changes from opt-in allowlist to opt-out denylist.

**Tech Stack:** Swift, IOKit (IOHIDManager), CoreGraphics (CGEventTap), XCTest

---

## File Map

| Action | File |
|--------|------|
| Create | `Sources/McMacWindowCore/IOHIDButtonTracker.swift` |
| Create | `Tests/McMacWindowTests/IOHIDButtonTrackerTests.swift` |
| Modify | `Package.swift` |
| Modify | `Sources/McMacWindowCore/MouseGestureManager.swift` |
| Modify | `Sources/McMacWindowCore/AppDelegate.swift` |
| Modify | `Tests/McMacWindowTests/MouseGestureManagerTests.swift` |
| Modify | `CLAUDE.md` |

---

## Task 1: Add IOKit to Package.swift

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Add IOKit linker setting**

In `Package.swift`, add `.linkedFramework("IOKit")` to `McMacWindowCore`'s `linkerSettings`:

```swift
.target(
    name: "McMacWindowCore",
    linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("ApplicationServices"),
        .linkedFramework("Carbon"),
        .linkedFramework("IOKit"),
    ]
),
```

- [ ] **Step 2: Verify build still passes**

```bash
./build.sh
```
Expected: build succeeds with no warnings.

- [ ] **Step 3: Commit**

```bash
git add Package.swift
git commit -m "build: add IOKit framework to McMacWindowCore"
```

---

## Task 2: Write failing IOHIDButtonTrackerTests

**Files:**
- Create: `Tests/McMacWindowTests/IOHIDButtonTrackerTests.swift`

These tests exercise `IOHIDButtonTracker.processButtonEvent` — an internal method we will define in Task 3. They will fail to compile until Task 3 is complete.

- [ ] **Step 1: Create the test file**

```swift
import XCTest
@testable import McMacWindowCore

final class IOHIDButtonTrackerTests: XCTestCase {

    var tracker: IOHIDButtonTracker!
    var downCount = 0
    var upCount = 0

    override func setUp() {
        super.setUp()
        tracker = IOHIDButtonTracker()
        tracker.onButtonDown = { [weak self] in self?.downCount += 1 }
        tracker.onButtonUp   = { [weak self] in self?.upCount   += 1 }
        tracker.resetCalibration()
        downCount = 0
        upCount   = 0
    }

    override func tearDown() {
        tracker.resetCalibration()
        super.tearDown()
    }

    func testFirstPressCalibrates() {
        tracker.processButtonEvent(usagePage: 0x09, usageID: 14, intValue: 1)
        XCTAssertEqual(downCount, 1)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "gestureButtonUsagePage"), 0x09)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "gestureButtonUsageID"), 14)
    }

    func testFirstReleaseIgnoredDuringCalibration() {
        tracker.processButtonEvent(usagePage: 0x09, usageID: 14, intValue: 0)
        XCTAssertEqual(downCount, 0)
        XCTAssertNil(UserDefaults.standard.object(forKey: "gestureButtonUsagePage"))
    }

    func testAfterCalibrationNonMatchingUsageIgnored() {
        tracker.processButtonEvent(usagePage: 0x09, usageID: 14, intValue: 1)
        downCount = 0
        tracker.processButtonEvent(usagePage: 0x09, usageID: 5, intValue: 1)
        XCTAssertEqual(downCount, 0)
    }

    func testButtonUpAfterCalibration() {
        tracker.processButtonEvent(usagePage: 0x09, usageID: 14, intValue: 1)
        tracker.processButtonEvent(usagePage: 0x09, usageID: 14, intValue: 0)
        XCTAssertEqual(upCount, 1)
    }

    func testNonButtonUsagePageIgnored() {
        tracker.processButtonEvent(usagePage: 0x01, usageID: 1, intValue: 1)
        XCTAssertEqual(downCount, 0)
    }

    func testResetCalibrationClearsStorage() {
        tracker.processButtonEvent(usagePage: 0x09, usageID: 14, intValue: 1)
        tracker.resetCalibration()
        XCTAssertNil(UserDefaults.standard.object(forKey: "gestureButtonUsagePage"))
        XCTAssertNil(UserDefaults.standard.object(forKey: "gestureButtonUsageID"))
    }

    func testAfterResetCalibratesWithNewUsage() {
        tracker.processButtonEvent(usagePage: 0x09, usageID: 14, intValue: 1)
        tracker.resetCalibration()
        downCount = 0
        tracker.processButtonEvent(usagePage: 0x09, usageID: 15, intValue: 1)
        XCTAssertEqual(downCount, 1)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "gestureButtonUsageID"), 15)
    }
}
```

- [ ] **Step 2: Verify tests fail to compile (class doesn't exist yet)**

```bash
./test.sh 2>&1 | head -20
```
Expected: compile error mentioning `IOHIDButtonTracker`.

---

## Task 3: Implement IOHIDButtonTracker

**Files:**
- Create: `Sources/McMacWindowCore/IOHIDButtonTracker.swift`

- [ ] **Step 1: Create the file**

```swift
import IOKit
import OSLog

private let logger = Logger(subsystem: "org.nathandrew.mcmac-window", category: "IOHIDButtonTracker")

private let kLogitechVendorID = 0x046D
private let kButtonUsagePage  = UInt32(0x09)   // kHIDPage_Button
private let kUDKeyUsagePage   = "gestureButtonUsagePage"
private let kUDKeyUsageID     = "gestureButtonUsageID"

public class IOHIDButtonTracker {

    public var onButtonDown: () -> Void = {}
    public var onButtonUp:   () -> Void = {}

    private var hidManager: IOHIDManager?

    public init() {}

    deinit { stop() }

    // MARK: - Lifecycle

    public func start() {
        guard hidManager == nil else { return }
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(
            mgr,
            [kIOHIDVendorIDKey as String: kLogitechVendorID] as CFDictionary
        )
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(mgr, { ctx, _, _, value in
            guard let ctx = ctx else { return }
            let tracker   = Unmanaged<IOHIDButtonTracker>.fromOpaque(ctx).takeUnretainedValue()
            let element   = IOHIDValueGetElement(value)
            let usagePage = IOHIDElementGetUsagePage(element)
            let usageID   = IOHIDElementGetUsage(element)
            let intValue  = IOHIDValueGetIntegerValue(value)
            tracker.processButtonEvent(usagePage: usagePage, usageID: usageID, intValue: intValue)
        }, ptr)
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = mgr
        logger.info("IOHIDButtonTracker started")
    }

    public func stop() {
        guard let mgr = hidManager else { return }
        IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
        hidManager = nil
        logger.info("IOHIDButtonTracker stopped")
    }

    public func resetCalibration() {
        UserDefaults.standard.removeObject(forKey: kUDKeyUsagePage)
        UserDefaults.standard.removeObject(forKey: kUDKeyUsageID)
        logger.info("IOHIDButtonTracker calibration reset")
    }

    // MARK: - Event processing (internal for testing)

    func processButtonEvent(usagePage: UInt32, usageID: UInt32, intValue: CFIndex) {
        guard usagePage == kButtonUsagePage else { return }

        let storedPage  = UserDefaults.standard.object(forKey: kUDKeyUsagePage)  as? Int
        let storedUsage = UserDefaults.standard.object(forKey: kUDKeyUsageID)    as? Int

        if storedPage == nil || storedUsage == nil {
            guard intValue == 1 else { return }
            UserDefaults.standard.set(Int(usagePage), forKey: kUDKeyUsagePage)
            UserDefaults.standard.set(Int(usageID),   forKey: kUDKeyUsageID)
            logger.info("Calibrated gesture button: page=\(usagePage) id=\(usageID)")
            onButtonDown()
            return
        }

        guard Int(usagePage) == storedPage, Int(usageID) == storedUsage else { return }
        if intValue == 1 { onButtonDown() } else { onButtonUp() }
    }
}
```

- [ ] **Step 2: Run the tests**

```bash
./test.sh
```
Expected: all `IOHIDButtonTrackerTests` pass. Other tests pass or skip.

- [ ] **Step 3: Commit**

```bash
git add Sources/McMacWindowCore/IOHIDButtonTracker.swift \
        Tests/McMacWindowTests/IOHIDButtonTrackerTests.swift
git commit -m "feat: add IOHIDButtonTracker with calibration-mode button detection"
```

---

## Task 4: Write updated MouseGestureManagerTests

**Files:**
- Modify: `Tests/McMacWindowTests/MouseGestureManagerTests.swift`

Replace the entire file. Old tests drove button state via `handleMouseDown/Up`; new tests use `manager.tracker.onButtonDown/Up()` (for tracker-integrated tests) or set `manager.gestureButtonHeld` directly (for unit tests of delta/threshold logic).

- [ ] **Step 1: Replace the file**

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

    // MARK: - Button state via tracker callbacks

    func testTrackerButtonDownSetsHeld() {
        manager.tracker.onButtonDown()
        XCTAssertTrue(manager.gestureButtonHeld)
    }

    func testTrackerButtonUpClearsHeld() {
        manager.tracker.onButtonDown()
        manager.tracker.onButtonUp()
        XCTAssertFalse(manager.gestureButtonHeld)
    }

    func testTrackerButtonUpResetsAccumulatedDelta() {
        manager.tracker.onButtonDown()
        manager.handleMouseMoved(dx: 30)
        manager.tracker.onButtonUp()
        XCTAssertEqual(manager.accumulatedDelta, 0)
    }

    // MARK: - Delta accumulation

    func testDeltaAccumulatesWhileButtonHeld() {
        manager.gestureButtonHeld = true
        manager.handleMouseMoved(dx: 20)
        manager.handleMouseMoved(dx: 15)
        XCTAssertEqual(manager.accumulatedDelta, 35)
    }

    func testDeltaIgnoredWhenButtonNotHeld() {
        manager.handleMouseMoved(dx: 100)
        XCTAssertEqual(manager.accumulatedDelta, 0)
        XCTAssertTrue(firedDirections.isEmpty)
    }

    func testRightThresholdTriggersSwitch() {
        manager.gestureButtonHeld = true
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
    }

    func testLeftThresholdTriggersSwitch() {
        manager.gestureButtonHeld = true
        manager.handleMouseMoved(dx: -60)
        XCTAssertEqual(firedDirections, [.left])
    }

    func testDeltaBelowThresholdDoesNotTrigger() {
        manager.gestureButtonHeld = true
        manager.handleMouseMoved(dx: 59)
        XCTAssertTrue(firedDirections.isEmpty)
    }

    func testDeltaResetsAfterTrigger() {
        manager.gestureButtonHeld = true
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(manager.accumulatedDelta, 0)
    }

    // MARK: - Denylist gating

    func testAppInDenylistSuppressesSwitch() {
        UserDefaults.standard.set(["com.test.app"], forKey: "gestureDisabledBundleIDs")
        manager.gestureButtonHeld = true
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
    }

    func testAppNotInDenylistAllowsSwitch() {
        manager.gestureButtonHeld = true
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
    }

    func testUnrelatedAppInDenylistDoesNotSuppressSwitch() {
        UserDefaults.standard.set(["com.other.app"], forKey: "gestureDisabledBundleIDs")
        manager.gestureButtonHeld = true
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
    }

    // MARK: - Pause gating

    func testSnappingPausedSuppressesSwitch() {
        manager.isSnappingPaused = { true }
        manager.gestureButtonHeld = true
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
    }

    // MARK: - Cooldown

    func testCooldownSuppressesImmediateRepeat() {
        manager.lastSwitchTime = Date()
        manager.gestureButtonHeld = true
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
    }

    func testSwitchFiresAfterCooldownExpires() {
        manager.lastSwitchTime = Date(timeIntervalSinceNow: -0.6)
        manager.gestureButtonHeld = true
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
    }

    func testCooldownResetsAccumulatedDelta() {
        manager.lastSwitchTime = Date()
        manager.gestureButtonHeld = true
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(manager.accumulatedDelta, 0)
    }

    // MARK: - Cmd+Tab suppression

    func testCmdTabSuppressedWhenButtonHeld() throws {
        guard let src = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: src, virtualKey: 48, keyDown: true) else {
            throw XCTSkip("Cannot create CGEvent in test environment")
        }
        event.flags = .maskCommand
        manager.gestureButtonHeld = true
        let result = manager.handleEvent(type: .keyDown, event: event)
        XCTAssertNil(result)
    }

    func testCmdTabPassesThroughWhenButtonNotHeld() throws {
        guard let src = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: src, virtualKey: 48, keyDown: true) else {
            throw XCTSkip("Cannot create CGEvent in test environment")
        }
        event.flags = .maskCommand
        manager.gestureButtonHeld = false
        let result = manager.handleEvent(type: .keyDown, event: event)
        XCTAssertNotNil(result)
    }

    func testCmdTabSuppressedWithinButtonDownTimeWindow() throws {
        guard let src = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: src, virtualKey: 48, keyDown: true) else {
            throw XCTSkip("Cannot create CGEvent in test environment")
        }
        event.flags = .maskCommand
        manager.gestureButtonHeld = false
        manager.lastButtonDownTime = Date()   // within 50ms window
        let result = manager.handleEvent(type: .keyDown, event: event)
        XCTAssertNil(result)
    }

    func testNonCmdKeyPassesThroughWhenButtonHeld() throws {
        guard let src = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true) else {
            throw XCTSkip("Cannot create CGEvent in test environment")
        }
        // no Command flag
        manager.gestureButtonHeld = true
        let result = manager.handleEvent(type: .keyDown, event: event)
        XCTAssertNotNil(result)
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

- [ ] **Step 2: Run tests — expect compile failures**

```bash
./test.sh 2>&1 | head -30
```
Expected: compile errors about missing `gestureButtonHeld` setter, missing `handleEvent`, missing `lastButtonDownTime`, removed `handleMouseDown`. This confirms the tests are driving the implementation.

---

## Task 5: Rework MouseGestureManager

**Files:**
- Modify: `Sources/McMacWindowCore/MouseGestureManager.swift`

Replace the entire file:

- [ ] **Step 1: Replace MouseGestureManager.swift**

```swift
import AppKit
import CoreGraphics
import OSLog

private let logger = Logger(subsystem: "org.nathandrew.mcmac-window", category: "MouseGestureManager")

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
    var gestureButtonHeld = false
    private(set) var accumulatedDelta: CGFloat = 0
    var lastSwitchTime: Date?
    var lastButtonDownTime: Date?

    // MARK: - IOHIDButtonTracker
    private(set) var tracker = IOHIDButtonTracker()

    // MARK: - Event tap
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {
        tracker.onButtonDown = { [weak self] in
            self?.gestureButtonHeld = true
            self?.lastButtonDownTime = Date()
        }
        tracker.onButtonUp = { [weak self] in
            self?.gestureButtonHeld = false
            self?.accumulatedDelta = 0
        }
    }

    deinit {
        stop()
    }

    // MARK: - Mouse moved

    func handleMouseMoved(dx: CGFloat) {
        guard gestureButtonHeld else { return }
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
        logger.debug("gesture threshold reached: \(direction == .right ? "right" : "left", privacy: .public)")
        switchAction(direction)
        accumulatedDelta = 0
        lastSwitchTime = Date()
    }

    private func gestureDisabledBundleIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: "gestureDisabledBundleIDs") ?? []
    }

    // MARK: - Event handling (internal for tests)

    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .mouseMoved:
            handleMouseMoved(dx: CGFloat(event.getDoubleValueField(.mouseEventDeltaX)))
        case .keyDown:
            let keyCode  = event.getIntegerValueField(.keyboardEventKeycode)
            let hasCmd   = event.flags.contains(.maskCommand)
            let inWindow = lastButtonDownTime.map { Date().timeIntervalSince($0) < 0.05 } ?? false
            if keyCode == 48 && hasCmd && (gestureButtonHeld || inWindow) {
                logger.debug("suppressing firmware Cmd+Tab")
                return nil
            }
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
        tracker.start()

        let eventMask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

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
        tracker.stop()
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
Expected: all tests pass or skip. Zero failures.

- [ ] **Step 3: Commit**

```bash
git add Sources/McMacWindowCore/MouseGestureManager.swift \
        Tests/McMacWindowTests/MouseGestureManagerTests.swift
git commit -m "feat: rework MouseGestureManager to use IOHIDButtonTracker"
git push
```

---

## Task 6: Update AppDelegate

**Files:**
- Modify: `Sources/McMacWindowCore/AppDelegate.swift`

Four changes: rename UDKey, add `recalibrateMenuItem` property, invert gesture menu logic, add recalibrate menu item.

- [ ] **Step 1: Rename the UDKey constant**

In the `UDKey` enum, replace:
```swift
static let gestureEnabledBundleIDs = "gestureEnabledBundleIDs"
```
with:
```swift
static let gestureDisabledBundleIDs = "gestureDisabledBundleIDs"
```

- [ ] **Step 2: Add recalibrate menu item property**

Add after `private var gestureMenuItem: NSMenuItem?`:
```swift
private var recalibrateMenuItem: NSMenuItem?
```

- [ ] **Step 3: Replace gesture menu item setup in setupStatusItem**

Find and replace the gesture item block (currently adds `gestureItem` to menu):
```swift
let gestureItem = NSMenuItem(title: "Enable Mouse Gesture for This App",
                             action: #selector(toggleGestureCurrentApp), keyEquivalent: "")
gestureItem.target = self
menu.addItem(gestureItem)
gestureMenuItem = gestureItem
menu.addItem(.separator())
```

Replace with:
```swift
let gestureItem = NSMenuItem(title: "Disable Mouse Gesture for This App",
                             action: #selector(toggleGestureCurrentApp), keyEquivalent: "")
gestureItem.target = self
menu.addItem(gestureItem)
gestureMenuItem = gestureItem

let recalibrateItem = NSMenuItem(title: "Re-calibrate Gesture Button",
                                 action: #selector(recalibrateGesture), keyEquivalent: "")
recalibrateItem.target = self
menu.addItem(recalibrateItem)
recalibrateMenuItem = recalibrateItem
menu.addItem(.separator())
```

- [ ] **Step 4: Replace the gesture helper methods**

Replace the entire `// MARK: - Mouse gesture allowlist` section:
```swift
// MARK: - Mouse gesture denylist

private func gestureDisabledBundleIDs() -> [String] {
    UserDefaults.standard.stringArray(forKey: UDKey.gestureDisabledBundleIDs) ?? []
}
private func setGestureDisabledBundleIDs(_ ids: [String]) {
    UserDefaults.standard.set(ids, forKey: UDKey.gestureDisabledBundleIDs)
}

@objc private func toggleGestureCurrentApp() {
    guard let app = NSWorkspace.shared.frontmostApplication,
          let bundleID = app.bundleIdentifier else { return }
    var ids = gestureDisabledBundleIDs()
    if let idx = ids.firstIndex(of: bundleID) { ids.remove(at: idx) } else { ids.append(bundleID) }
    setGestureDisabledBundleIDs(ids)
}

@objc private func recalibrateGesture() {
    MouseGestureManager.shared.tracker.resetCalibration()
}

private func updateGestureMenuItem() {
    let paused = isSnappingPaused()
    gestureMenuItem?.isHidden = paused
    recalibrateMenuItem?.isHidden = paused
    guard !paused,
          let app = NSWorkspace.shared.frontmostApplication,
          let bundleID = app.bundleIdentifier,
          bundleID != Bundle.main.bundleIdentifier else {
        gestureMenuItem?.title = "Disable Mouse Gesture for This App"
        gestureMenuItem?.isEnabled = false
        return
    }
    let name = app.localizedName ?? bundleID
    let isDisabled = gestureDisabledBundleIDs().contains(bundleID)
    gestureMenuItem?.title = isDisabled
        ? "Enable Mouse Gesture for \(name)"
        : "Disable Mouse Gesture for \(name)"
    gestureMenuItem?.isEnabled = true
}
```

- [ ] **Step 5: Build and test**

```bash
./build.sh && ./test.sh
```
Expected: clean build, all tests pass or skip.

- [ ] **Step 6: Commit**

```bash
git add Sources/McMacWindowCore/AppDelegate.swift
git commit -m "feat: invert gesture menu to opt-out denylist, add re-calibrate item"
git push
```

---

## Task 7: Update CLAUDE.md documentation

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update the mouse gesture configuration section**

Find:
```
Configuration (via `UserDefaults`):
- `gestureButtonIndex` (Int, default 3) — raw button number for the gesture button; override if your MX model reports a different value
- `gestureEnabledBundleIDs` ([String]) — the per-app allowlist managed by the menu
```

Replace with:
```
Configuration (via `UserDefaults`):
- `gestureButtonUsagePage` (Int) — HID usage page of the gesture button; stored automatically on first press (calibration)
- `gestureButtonUsageID` (Int) — HID usage ID of the gesture button; stored automatically on first press (calibration)
- `gestureDisabledBundleIDs` ([String]) — the per-app denylist managed by the menu
```

- [ ] **Step 2: Update the feature description line**

Find:
```
The feature is **opt-in per application**. Use "Enable Mouse Gesture for [App]" in the menu bar to add or remove the frontmost app from the allowlist.
```

Replace with:
```
The feature is **opt-out per application**. Use "Disable Mouse Gesture for [App]" in the menu bar to add or remove the frontmost app from the denylist. Use "Re-calibrate Gesture Button" to re-learn the button's HID usage (needed if the button mapping changes or on first launch).
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for IOHIDManager gesture rework"
git push
```
