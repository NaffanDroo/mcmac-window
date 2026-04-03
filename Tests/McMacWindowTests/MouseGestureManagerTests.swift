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
        UserDefaults.standard.removeObject(forKey: UDKey.gestureDisabledBundleIDs.rawValue)
        firedDirections = []
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: UDKey.gestureDisabledBundleIDs.rawValue)
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
        XCTAssertFalse(manager.gestureWindowOpen)
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
        UserDefaults.standard.set(["com.test.app"], forKey: UDKey.gestureDisabledBundleIDs.rawValue)
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 60)
        XCTAssertTrue(firedDirections.isEmpty)
        XCTAssertTrue(manager.gestureWindowOpen)
    }

    func testAppNotInDenylistAllowsSwitch() {
        manager.gestureWindowOpen = true
        manager.gestureWindowOpened = Date()
        manager.handleMouseMoved(dx: 60)
        XCTAssertEqual(firedDirections, [.right])
    }

    func testUnrelatedAppInDenylistDoesNotSuppressSwitch() {
        UserDefaults.standard.set(["com.other.app"], forKey: UDKey.gestureDisabledBundleIDs.rawValue)
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
        XCTAssertTrue(manager.gestureWindowOpen)
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
