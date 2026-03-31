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
        tracker = nil
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
        XCTAssertEqual(upCount, 0)
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
