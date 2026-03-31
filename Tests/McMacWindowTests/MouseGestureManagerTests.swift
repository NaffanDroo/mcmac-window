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
}
