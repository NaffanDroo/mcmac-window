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
