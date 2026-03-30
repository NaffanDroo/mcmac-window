# Mouse Gesture Desktop Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add opt-in per-app support for the Logitech MX gesture button (held + left/right mouse movement) to switch macOS desktops without requiring Logi Options+.

**Architecture:** A new `MouseGestureManager` singleton installs a passive `CGEventTap` that observes `otherMouseDown/Up/Dragged` events. It accumulates horizontal delta while the gesture button is held, and fires `^→`/`^←` key events when the delta crosses a threshold and the frontmost app is in the per-app allowlist. `AppDelegate` adds two menu items (enable/disable for current app) mirroring the existing ignore-list pattern.

**Tech Stack:** Swift, CoreGraphics (`CGEventTap`, `CGEventPost`), AppKit (`NSWorkspace`), OSLog, XCTest

---

## File Map

| File | Status | Responsibility |
|------|--------|----------------|
| `Sources/McMacWindowCore/MouseGestureManager.swift` | Create | Event tap, state machine, space switching |
| `Sources/McMacWindowCore/AppDelegate.swift` | Modify | Per-app gesture allowlist menu items |
| `Tests/McMacWindowTests/MouseGestureManagerTests.swift` | Create | Unit tests for state machine |

---

### Task 1: Branch + `MouseGestureManager` skeleton with button-state tracking

**Files:**
- Create: `Sources/McMacWindowCore/MouseGestureManager.swift`
- Create: `Tests/McMacWindowTests/MouseGestureManagerTests.swift`

- [ ] **Step 1: Create the branch**

```bash
git checkout -b feat/mouse-gesture-desktop-switching
git push -u origin feat/mouse-gesture-desktop-switching
```

- [ ] **Step 2: Write the failing tests**

Create `Tests/McMacWindowTests/MouseGestureManagerTests.swift`:

```swift
import XCTest
import ApplicationServices
@testable import McMacWindowCore

final class MouseGestureManagerTests: XCTestCase {

    var manager: MouseGestureManager!
    var firedDirections: [GestureDirection] = []

    override func setUp() {
        super.setUp()
        manager = MouseGestureManager()
        manager.gestureButtonIndex = 3
        manager.switchAction = { [weak self] dir in self?.firedDirections.append(dir) }
        manager.frontmostBundleID = { "com.test.app" }
        manager.isSnappingPaused = { false }
        UserDefaults.standard.set(["com.test.app"], forKey: "gestureEnabledBundleIDs")
        firedDirections = []
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "gestureEnabledBundleIDs")
        super.tearDown()
    }

    // MARK: - Button state

    func testGestureButtonDownSetsHeld() {
        manager.handleMouseDown(button: 3)
        XCTAssertTrue(manager.gestureButtonHeld)
    }

    func testOtherButtonDownDoesNotSetHeld() {
        manager.handleMouseDown(button: 2)
        XCTAssertFalse(manager.gestureButtonHeld)
    }

    func testGestureButtonUpClearsHeld() {
        manager.handleMouseDown(button: 3)
        manager.handleMouseUp(button: 3)
        XCTAssertFalse(manager.gestureButtonHeld)
    }

    func testButtonUpResetsAccumulatedDelta() {
        manager.handleMouseDown(button: 3)
        manager.handleMouseMoved(dx: 30)
        manager.handleMouseUp(button: 3)
        XCTAssertEqual(manager.accumulatedDelta, 0)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
./test.sh 2>&1 | grep -E "error:|FAILED|MouseGesture"
```

Expected: compile error — `MouseGestureManager` and `GestureDirection` do not exist yet.

- [ ] **Step 4: Create the skeleton**

Create `Sources/McMacWindowCore/MouseGestureManager.swift`:

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
    var gestureButtonIndex: Int = 3
    var deltaThreshold: CGFloat = 60
    var cooldown: TimeInterval = 0.5

    // MARK: - State
    private(set) var gestureButtonHeld = false
    private(set) var accumulatedDelta: CGFloat = 0
    var lastSwitchTime: Date?

    // MARK: - Event tap
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {}

    // MARK: - Button state

    func handleMouseDown(button: Int) {
        guard button == gestureButtonIndex else { return }
        gestureButtonHeld = true
        logger.debug("gesture button down")
    }

    func handleMouseUp(button: Int) {
        guard button == gestureButtonIndex else { return }
        gestureButtonHeld = false
        accumulatedDelta = 0
        logger.debug("gesture button up, delta reset")
    }

    func handleMouseMoved(dx: CGFloat) {
        // implemented in Task 2
    }

    // MARK: - Space switching (implemented in Task 5)

    static func postSpaceSwitch(direction: GestureDirection) {}

    // MARK: - Event tap (implemented in Task 5)

    public func start() {}
    public func stop() {}
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
./test.sh 2>&1 | grep -E "PASSED|FAILED|error:"
```

Expected: all four `MouseGestureManagerTests` pass; all other tests continue to pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/McMacWindowCore/MouseGestureManager.swift \
        Tests/McMacWindowTests/MouseGestureManagerTests.swift
git commit -m "feat: add MouseGestureManager skeleton with button state tracking"
git push
```

---

### Task 2: Delta accumulation and threshold

**Files:**
- Modify: `Sources/McMacWindowCore/MouseGestureManager.swift`
- Modify: `Tests/McMacWindowTests/MouseGestureManagerTests.swift`

- [ ] **Step 1: Add the failing tests**

Append the following inside `MouseGestureManagerTests` (after `testButtonUpResetsAccumulatedDelta`):

```swift
// MARK: - Delta accumulation

func testDeltaAccumulatesWhileButtonHeld() {
    manager.handleMouseDown(button: 3)
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
    manager.handleMouseDown(button: 3)
    manager.handleMouseMoved(dx: 60)
    XCTAssertEqual(firedDirections, [.right])
}

func testLeftThresholdTriggersSwitch() {
    manager.handleMouseDown(button: 3)
    manager.handleMouseMoved(dx: -60)
    XCTAssertEqual(firedDirections, [.left])
}

func testDeltaBelowThresholdDoesNotTrigger() {
    manager.handleMouseDown(button: 3)
    manager.handleMouseMoved(dx: 59)
    XCTAssertTrue(firedDirections.isEmpty)
}

func testDeltaResetsAfterTrigger() {
    manager.handleMouseDown(button: 3)
    manager.handleMouseMoved(dx: 60)
    XCTAssertEqual(manager.accumulatedDelta, 0)
}
```

- [ ] **Step 2: Run tests to verify the new tests fail**

```bash
./test.sh 2>&1 | grep -E "PASSED|FAILED|error:"
```

Expected: the six new delta tests fail (no switch fires; delta stays at 0).

- [ ] **Step 3: Implement `handleMouseMoved` with delta + threshold**

Replace the `handleMouseMoved` stub in `MouseGestureManager.swift`:

```swift
func handleMouseMoved(dx: CGFloat) {
    guard gestureButtonHeld else { return }

    accumulatedDelta += dx
    guard abs(accumulatedDelta) >= deltaThreshold else { return }

    let direction: GestureDirection = accumulatedDelta > 0 ? .right : .left
    logger.debug("gesture threshold reached: \(direction == .right ? "right" : "left", privacy: .public)")
    switchAction(direction)
    accumulatedDelta = 0
    lastSwitchTime = Date()
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
./test.sh 2>&1 | grep -E "PASSED|FAILED|error:"
```

Expected: all ten tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/McMacWindowCore/MouseGestureManager.swift \
        Tests/McMacWindowTests/MouseGestureManagerTests.swift
git commit -m "feat: accumulate horizontal delta and fire switch at threshold"
git push
```

---

### Task 3: Allowlist and snapping-pause gating

**Files:**
- Modify: `Sources/McMacWindowCore/MouseGestureManager.swift`
- Modify: `Tests/McMacWindowTests/MouseGestureManagerTests.swift`

- [ ] **Step 1: Add the failing tests**

Append inside `MouseGestureManagerTests`:

```swift
// MARK: - Allowlist gating

func testAppNotInAllowlistSuppressesSwitch() {
    UserDefaults.standard.set(["com.other.app"], forKey: "gestureEnabledBundleIDs")
    manager.handleMouseDown(button: 3)
    manager.handleMouseMoved(dx: 60)
    XCTAssertTrue(firedDirections.isEmpty)
}

func testAppInAllowlistAllowsSwitch() {
    // setUp puts "com.test.app" in the list; frontmostBundleID returns "com.test.app"
    manager.handleMouseDown(button: 3)
    manager.handleMouseMoved(dx: 60)
    XCTAssertEqual(firedDirections, [.right])
}

func testEmptyAllowlistSuppressesSwitch() {
    UserDefaults.standard.set([], forKey: "gestureEnabledBundleIDs")
    manager.handleMouseDown(button: 3)
    manager.handleMouseMoved(dx: 60)
    XCTAssertTrue(firedDirections.isEmpty)
}

// MARK: - Pause gating

func testSnappingPausedSuppressesSwitch() {
    manager.isSnappingPaused = { true }
    manager.handleMouseDown(button: 3)
    manager.handleMouseMoved(dx: 60)
    XCTAssertTrue(firedDirections.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify the new tests fail**

```bash
./test.sh 2>&1 | grep -E "PASSED|FAILED|error:"
```

Expected: `testAppNotInAllowlistSuppressesSwitch`, `testEmptyAllowlistSuppressesSwitch`, and `testSnappingPausedSuppressesSwitch` fail (no gating in place yet).

- [ ] **Step 3: Add the gating checks and private helper**

Replace `handleMouseMoved` in `MouseGestureManager.swift`:

```swift
func handleMouseMoved(dx: CGFloat) {
    guard gestureButtonHeld else { return }
    guard let bundleID = frontmostBundleID(),
          gestureEnabledBundleIDs().contains(bundleID) else { return }
    guard !isSnappingPaused() else { return }

    accumulatedDelta += dx
    guard abs(accumulatedDelta) >= deltaThreshold else { return }

    let direction: GestureDirection = accumulatedDelta > 0 ? .right : .left
    logger.debug("gesture threshold reached: \(direction == .right ? "right" : "left", privacy: .public)")
    switchAction(direction)
    accumulatedDelta = 0
    lastSwitchTime = Date()
}
```

Add the private helper immediately after `handleMouseMoved`:

```swift
private func gestureEnabledBundleIDs() -> [String] {
    UserDefaults.standard.stringArray(forKey: "gestureEnabledBundleIDs") ?? []
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
./test.sh 2>&1 | grep -E "PASSED|FAILED|error:"
```

Expected: all fourteen tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/McMacWindowCore/MouseGestureManager.swift \
        Tests/McMacWindowTests/MouseGestureManagerTests.swift
git commit -m "feat: gate gesture on per-app allowlist and snapping-pause state"
git push
```

---

### Task 4: Cooldown

**Files:**
- Modify: `Sources/McMacWindowCore/MouseGestureManager.swift`
- Modify: `Tests/McMacWindowTests/MouseGestureManagerTests.swift`

- [ ] **Step 1: Add the failing tests**

Append inside `MouseGestureManagerTests`:

```swift
// MARK: - Cooldown

func testCooldownSuppressesImmediateRepeat() {
    manager.lastSwitchTime = Date()   // simulate a switch that just fired
    manager.handleMouseDown(button: 3)
    manager.handleMouseMoved(dx: 60)
    XCTAssertTrue(firedDirections.isEmpty)
}

func testSwitchFiresAfterCooldownExpires() {
    manager.lastSwitchTime = Date(timeIntervalSinceNow: -0.6)   // 600ms ago
    manager.handleMouseDown(button: 3)
    manager.handleMouseMoved(dx: 60)
    XCTAssertEqual(firedDirections, [.right])
}
```

- [ ] **Step 2: Run tests to verify the new tests fail**

```bash
./test.sh 2>&1 | grep -E "PASSED|FAILED|error:"
```

Expected: `testCooldownSuppressesImmediateRepeat` fails (switch fires immediately with no cooldown check).

- [ ] **Step 3: Add the cooldown guard to `handleMouseMoved`**

Replace `handleMouseMoved` in `MouseGestureManager.swift`:

```swift
func handleMouseMoved(dx: CGFloat) {
    guard gestureButtonHeld else { return }
    guard let bundleID = frontmostBundleID(),
          gestureEnabledBundleIDs().contains(bundleID) else { return }
    guard !isSnappingPaused() else { return }

    accumulatedDelta += dx
    guard abs(accumulatedDelta) >= deltaThreshold else { return }
    if let last = lastSwitchTime, Date().timeIntervalSince(last) < cooldown { return }

    let direction: GestureDirection = accumulatedDelta > 0 ? .right : .left
    logger.debug("gesture threshold reached: \(direction == .right ? "right" : "left", privacy: .public)")
    switchAction(direction)
    accumulatedDelta = 0
    lastSwitchTime = Date()
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
./test.sh 2>&1 | grep -E "PASSED|FAILED|error:"
```

Expected: all sixteen tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/McMacWindowCore/MouseGestureManager.swift \
        Tests/McMacWindowTests/MouseGestureManagerTests.swift
git commit -m "feat: suppress rapid-fire gestures with 500ms cooldown"
git push
```

---

### Task 5: `postSpaceSwitch` + `CGEventTap` wiring

**Files:**
- Modify: `Sources/McMacWindowCore/MouseGestureManager.swift`
- Modify: `Tests/McMacWindowTests/MouseGestureManagerTests.swift`

- [ ] **Step 1: Add the integration test (with XCTSkip guard)**

Append inside `MouseGestureManagerTests`:

```swift
// MARK: - CGEventTap (requires Accessibility permission)

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
```

- [ ] **Step 2: Implement `postSpaceSwitch`**

Replace the `postSpaceSwitch` stub in `MouseGestureManager.swift`:

```swift
static func postSpaceSwitch(direction: GestureDirection) {
    let keyCode: CGKeyCode = direction == .right ? 124 : 123   // right / left arrow
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
```

- [ ] **Step 3: Implement `start()`, `stop()`, and the event dispatcher**

Replace the `start()` and `stop()` stubs and add `handleEvent` + `eventTapIsEnabled` in `MouseGestureManager.swift`:

```swift
public func start() {
    if let stored = UserDefaults.standard.object(forKey: "gestureButtonIndex") as? Int {
        gestureButtonIndex = stored
    }

    let eventMask: CGEventMask =
        (1 << CGEventType.otherMouseDown.rawValue) |
        (1 << CGEventType.otherMouseUp.rawValue)   |
        (1 << CGEventType.otherMouseDragged.rawValue)

    let selfPtr = Unmanaged.passUnretained(self).toOpaque()
    guard let tap = CGEventTapCreate(
        .cghidEventTap,
        .headInsertEventTap,
        .listenOnly,
        eventMask,
        { _, type, event, userInfo -> Unmanaged<CGEvent>? in
            guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
            let mgr = Unmanaged<MouseGestureManager>.fromOpaque(userInfo).takeUnretainedValue()
            mgr.handleEvent(type: type, event: event)
            return Unmanaged.passUnretained(event)
        },
        selfPtr
    ) else {
        logger.error("CGEventTap creation failed — Accessibility permission likely not granted")
        return
    }

    eventTap = tap
    let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
    runLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    CGEventTapEnable(tap, true)
    logger.info("MouseGestureManager started, monitoring button \(self.gestureButtonIndex)")
}

public func stop() {
    if let tap = eventTap { CGEventTapEnable(tap, false) }
    if let src = runLoopSource {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
    }
    eventTap = nil
    runLoopSource = nil
    logger.info("MouseGestureManager stopped")
}

private func handleEvent(type: CGEventType, event: CGEvent) {
    switch type {
    case .otherMouseDown:
        handleMouseDown(button: Int(event.getIntegerValueField(.mouseEventButtonNumber)))
    case .otherMouseUp:
        handleMouseUp(button: Int(event.getIntegerValueField(.mouseEventButtonNumber)))
    case .otherMouseDragged:
        handleMouseMoved(dx: CGFloat(event.getDoubleValueField(.mouseEventDeltaX)))
    default:
        break
    }
}

/// Exposed for testing only — returns whether the tap exists and is enabled.
var eventTapIsEnabled: Bool? {
    guard let tap = eventTap else { return nil }
    return CGEventTapIsEnabled(tap)
}
```

- [ ] **Step 4: Run tests**

```bash
./test.sh 2>&1 | grep -E "PASSED|FAILED|SKIPPED|error:"
```

Expected: all sixteen prior tests pass; `testStartCreatesTap` is skipped in CI (no AX permission).

- [ ] **Step 5: Commit**

```bash
git add Sources/McMacWindowCore/MouseGestureManager.swift \
        Tests/McMacWindowTests/MouseGestureManagerTests.swift
git commit -m "feat: implement postSpaceSwitch and CGEventTap wiring"
git push
```

---

### Task 6: `AppDelegate` menu items

**Files:**
- Modify: `Sources/McMacWindowCore/AppDelegate.swift`

- [ ] **Step 1: Add the stored property**

In `AppDelegate.swift`, add `gestureMenuItem` alongside the other stored menu item properties (after `manageIgnoredMenuItem`):

```swift
private var gestureMenuItem: NSMenuItem?
```

- [ ] **Step 2: Add the menu item in `setupStatusItem()`**

In `setupStatusItem()`, insert the following block immediately after the `manageIgnoredMenuItem` wiring (before the separator that precedes the Shortcuts item):

```swift
let gestureItem = NSMenuItem(title: "Enable Mouse Gesture for This App",
                             action: #selector(toggleGestureCurrentApp), keyEquivalent: "")
gestureItem.target = self
menu.addItem(gestureItem)
gestureMenuItem = gestureItem
```

- [ ] **Step 3: Add the allowlist helpers and toggle action**

Add a new `// MARK: - Mouse gesture allowlist` section to `AppDelegate.swift` (after the existing `// MARK: - Per-app ignore list` section):

```swift
// MARK: - Mouse gesture allowlist

private func gestureEnabledBundleIDs() -> [String] {
    UserDefaults.standard.stringArray(forKey: "gestureEnabledBundleIDs") ?? []
}

private func setGestureEnabledBundleIDs(_ ids: [String]) {
    UserDefaults.standard.set(ids, forKey: "gestureEnabledBundleIDs")
}

@objc private func toggleGestureCurrentApp() {
    guard let app = NSWorkspace.shared.frontmostApplication,
          let bundleID = app.bundleIdentifier else { return }
    var ids = gestureEnabledBundleIDs()
    if let idx = ids.firstIndex(of: bundleID) {
        ids.remove(at: idx)
    } else {
        ids.append(bundleID)
    }
    setGestureEnabledBundleIDs(ids)
}

private func updateGestureMenuItem() {
    let paused = isSnappingPaused()
    gestureMenuItem?.isHidden = paused
    guard !paused,
          let app = NSWorkspace.shared.frontmostApplication,
          let bundleID = app.bundleIdentifier,
          bundleID != Bundle.main.bundleIdentifier else {
        gestureMenuItem?.title = "Enable Mouse Gesture for This App"
        gestureMenuItem?.isEnabled = false
        return
    }
    let name = app.localizedName ?? bundleID
    let isEnabled = gestureEnabledBundleIDs().contains(bundleID)
    gestureMenuItem?.title = isEnabled
        ? "✓ Mouse Gesture for \(name)"
        : "Enable Mouse Gesture for \(name)"
    gestureMenuItem?.isEnabled = true
}
```

- [ ] **Step 4: Call `updateGestureMenuItem()` in `menuWillOpen`**

In the `NSMenuDelegate` extension, update `menuWillOpen` to:

```swift
public func menuWillOpen(_ menu: NSMenu) {
    updateAccessibilityMenuItem()
    updatePauseMenuItem()
    updateIgnoreMenuItem()
    updateGestureMenuItem()
}
```

- [ ] **Step 5: Build with warnings-as-errors**

```bash
./build.sh --warnings-as-errors 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Sources/McMacWindowCore/AppDelegate.swift
git commit -m "feat: add per-app mouse gesture toggle to menu bar"
git push
```

---

### Task 7: Wire `start()` into launch + final verification

**Files:**
- Modify: `Sources/McMacWindowCore/AppDelegate.swift`

- [ ] **Step 1: Call `MouseGestureManager.shared.start()` in `applicationDidFinishLaunching`**

In `AppDelegate.swift`, add the call directly after `HotkeyManager.shared.register()`:

```swift
HotkeyManager.shared.register()
MouseGestureManager.shared.start()
```

- [ ] **Step 2: Run the full build + test pipeline**

```bash
./build.sh --warnings-as-errors && ./test.sh
```

Expected: `** BUILD SUCCEEDED **` followed by all tests passing (the CGEventTap integration test is skipped in headless CI).

- [ ] **Step 3: Commit**

```bash
git add Sources/McMacWindowCore/AppDelegate.swift
git commit -m "feat: start MouseGestureManager on app launch"
git push
```
