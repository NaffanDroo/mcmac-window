import ApplicationServices
import CoreGraphics
import XCTest

@testable import McMacWindowCore

final class MouseGestureManagerTests: XCTestCase {

    var manager: MouseGestureManager!
    var firedDirections: [GestureDirection] = []
    var mockButtonTracker: MockIOHIDButtonTracker!

    override func setUp() {
        super.setUp()
        manager = MouseGestureManager()
        manager.switchAction = { [weak self] dir in self?.firedDirections.append(dir) }
        manager.frontmostBundleID = { "com.test.app" }
        manager.isSnappingPaused = { false }

        // Inject mock button tracker
        mockButtonTracker = MockIOHIDButtonTracker()
        manager.buttonTracker = mockButtonTracker

        UserDefaults.standard.removeObject(forKey: UDKey.gestureDisabledBundleIDs.rawValue)
        firedDirections = []
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: UDKey.gestureDisabledBundleIDs.rawValue)
        super.tearDown()
    }

    // MARK: - Button state opening/closing gesture window

    func testButtonDownOpensGestureWindow() {
        XCTAssertFalse(manager.gestureWindowOpen)
        manager.handleButtonDown()
        XCTAssertTrue(manager.gestureWindowOpen)
    }

    func testButtonUpClosesGestureWindow() {
        manager.handleButtonDown()
        manager.handleButtonUp()
        XCTAssertFalse(manager.gestureWindowOpen)
    }

    func testButtonDownResetsAccumulatedDelta() {
        manager.accumulatedDelta = 50
        manager.handleButtonDown()
        XCTAssertEqual(manager.accumulatedDelta, 0)
    }

    func testButtonUpResetsAccumulatedDelta() {
        manager.gestureWindowOpen = true
        manager.accumulatedDelta = 100
        manager.handleButtonUp()
        XCTAssertEqual(manager.accumulatedDelta, 0)
    }

    // MARK: - Mouse movement while button held

    func testMouseMovementRightWhenButtonHeld() {
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
    }

    func testMouseMovementLeftWhenButtonHeld() {
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: -60)
        XCTAssertEqual(firedDirections, [.left])
    }

    func testMouseMovementIgnoredWhenButtonNotHeld() {
        manager.handleMouseMoved(dx: 100)
        XCTAssertTrue(firedDirections.isEmpty)
    }

    func testSmallMovementsAccumulate() {
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 20)
        manager.handleMouseMoved(dx: 20)
        manager.handleMouseMoved(dx: 20)
        XCTAssertEqual(
            firedDirections.count, 1, "Should fire when accumulated delta reaches threshold")
        XCTAssertEqual(firedDirections.first, .right)
    }

    func testMovementBelowThresholdDoesNotFire() {
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 59)
        XCTAssertTrue(firedDirections.isEmpty)
        XCTAssertEqual(manager.accumulatedDelta, 59)
    }

    func testMixedDirectionsAccumulate() {
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 50)
        manager.handleMouseMoved(dx: -40)
        XCTAssertEqual(manager.accumulatedDelta, 10)
        XCTAssertTrue(firedDirections.isEmpty)

        manager.handleMouseMoved(dx: -80)
        XCTAssertEqual(firedDirections.count, 1)
        XCTAssertEqual(firedDirections.first, .left)
    }

    // MARK: - Gesture window lifecycle

    func testButtonCycleClearsState() {
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections.count, 1)

        manager.handleButtonUp()
        XCTAssertFalse(manager.gestureWindowOpen)
        XCTAssertEqual(manager.accumulatedDelta, 0)
    }

    func testReleaseWithoutThresholdClearsState() {
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 30)
        manager.handleButtonUp()
        XCTAssertTrue(firedDirections.isEmpty)
        XCTAssertFalse(manager.gestureWindowOpen)
        XCTAssertEqual(manager.accumulatedDelta, 0)
    }

    // MARK: - Denylist gating

    func testAppInDenylistSuppressesSwitch() {
        UserDefaults.standard.set(["com.test.app"], forKey: UDKey.gestureDisabledBundleIDs.rawValue)
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
        XCTAssertTrue(manager.gestureWindowOpen)
    }

    func testAppNotInDenylistAllowsSwitch() {
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
    }

    func testUnrelatedAppInDenylistDoesNotSuppressSwitch() {
        UserDefaults.standard.set(
            ["com.other.app"], forKey: UDKey.gestureDisabledBundleIDs.rawValue)
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
    }

    func testNoFrontmostAppSuppressesSwitch() {
        manager.frontmostBundleID = { nil }
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
    }

    // MARK: - Pause gating

    func testSnappingPausedSuppressesSwitch() {
        manager.isSnappingPaused = { true }
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
        XCTAssertTrue(manager.gestureWindowOpen)
    }

    // MARK: - Cooldown

    func testCooldownSuppressesImmediateRepeat() {
        manager.lastSwitchTime = Date()
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
        XCTAssertEqual(manager.accumulatedDelta, 0)
    }

    func testSwitchFiresAfterCooldownExpires() {
        manager.lastSwitchTime = Date(timeIntervalSinceNow: -0.6)
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
    }

    // MARK: - Complete flow with physical button

    func testCompleteFlow_ButtonDownMouseMovement_FiresSwitch() {
        manager.handleButtonDown()
        XCTAssertTrue(manager.gestureWindowOpen)

        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections.count, 1)
        XCTAssertEqual(firedDirections.first, .right)
    }

    func testCompleteFlow_MultipleButtonCycles() {
        // First gesture
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 60)
        manager.handleButtonUp()

        // Clear cooldown so second gesture can fire
        manager.lastSwitchTime = nil

        // Second gesture
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: -60)
        manager.handleButtonUp()

        XCTAssertEqual(firedDirections.count, 2)
        XCTAssertEqual(firedDirections[0], .right)
        XCTAssertEqual(firedDirections[1], .left)
    }

    func testCompleteFlow_ReleaseBeforeThresholdDoesntFire() {
        manager.handleButtonDown()
        manager.handleMouseMoved(dx: 50)
        manager.handleButtonUp()
        XCTAssertTrue(firedDirections.isEmpty)
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

// MARK: - Mock Button Tracker

class MockIOHIDButtonTracker: IOHIDButtonTracker {
    override func start() {
        // No-op for tests
    }

    override func stop() {
        // No-op for tests
    }
}
