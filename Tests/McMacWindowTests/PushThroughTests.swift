import XCTest
@testable import McMacWindowCore

// Shared screen layouts for push-through / adjacentScreen tests (AppKit coords).
// Horizontal: A (primary, has menu bar) | B | C
let screenA = ScreenInfo(frame: CGRect(x:    0, y: 0, width: 1920, height: 1080),
                         visibleFrame: CGRect(x:    0, y: 23, width: 1920, height: 1057))
let screenB = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                         visibleFrame: CGRect(x: 1920, y:  0, width: 1920, height: 1080))
let screenC = ScreenInfo(frame: CGRect(x: 3840, y: 0, width: 1920, height: 1080),
                         visibleFrame: CGRect(x: 3840, y:  0, width: 1920, height: 1080))
// Vertical: bottom (primary) | top
let screenBottom = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                              visibleFrame: CGRect(x: 0, y: 23, width: 1920, height: 1057))
let screenTop    = ScreenInfo(frame: CGRect(x: 0, y: 1080, width: 1920, height: 1080),
                              visibleFrame: CGRect(x: 0, y: 1080, width: 1920, height: 1080))

class PushThroughTests: XCTestCase {

    // MARK: - adjacentScreen: horizontal

    func testAdjacentScreenLeftOfBReturnsA() {
        let result = adjacentScreen(to: screenB.visibleFrame, direction: .left,
                                    among: [screenA, screenB, screenC])
        XCTAssertEqual(result?.visibleFrame ?? .zero, screenA.visibleFrame, "should return screen A")
    }

    func testAdjacentScreenRightOfBReturnsC() {
        let result = adjacentScreen(to: screenB.visibleFrame, direction: .right,
                                    among: [screenA, screenB, screenC])
        XCTAssertEqual(result?.visibleFrame ?? .zero, screenC.visibleFrame, "should return screen C")
    }

    func testAdjacentScreenNoScreenLeftOfLeftmost() {
        XCTAssertNil(adjacentScreen(to: screenA.visibleFrame, direction: .left, among: [screenA, screenB]),
                     "leftmost screen has no left neighbour")
    }

    func testAdjacentScreenNoScreenRightOfRightmost() {
        XCTAssertNil(adjacentScreen(to: screenB.visibleFrame, direction: .right, among: [screenA, screenB]),
                     "rightmost screen has no right neighbour")
    }

    func testAdjacentScreenSingleScreenHasNoNeighbours() {
        XCTAssertNil(adjacentScreen(to: screenA.visibleFrame, direction: .left, among: [screenA]))
        XCTAssertNil(adjacentScreen(to: screenA.visibleFrame, direction: .right, among: [screenA]))
    }

    // MARK: - pushThrough(for:)

    func testPushThroughLeftHalf() {
        let pt = pushThrough(for: .leftHalf)
        XCTAssertTrue(pt?.action == .rightHalf, "mirror action")
        XCTAssertTrue(pt?.direction == .left, "direction")
    }

    func testPushThroughRightHalf() {
        let pt = pushThrough(for: .rightHalf)
        XCTAssertTrue(pt?.action == .leftHalf, "mirror action")
        XCTAssertTrue(pt?.direction == .right, "direction")
    }

    func testPushThroughTopHalf() {
        let pt = pushThrough(for: .topHalf)
        XCTAssertTrue(pt?.action == .bottomHalf, "mirror action")
        XCTAssertTrue(pt?.direction == .up, "direction")
    }

    func testPushThroughBottomHalf() {
        let pt = pushThrough(for: .bottomHalf)
        XCTAssertTrue(pt?.action == .topHalf, "mirror action")
        XCTAssertTrue(pt?.direction == .down, "direction")
    }

    func testPushThroughTopLeft() {
        let pt = pushThrough(for: .topLeft)
        XCTAssertTrue(pt?.action == .topRight, "mirror action")
        XCTAssertTrue(pt?.direction == .left, "direction")
    }

    func testPushThroughTopRight() {
        let pt = pushThrough(for: .topRight)
        XCTAssertTrue(pt?.action == .topLeft, "mirror action")
        XCTAssertTrue(pt?.direction == .right, "direction")
    }

    func testPushThroughBottomLeft() {
        let pt = pushThrough(for: .bottomLeft)
        XCTAssertTrue(pt?.action == .bottomRight, "mirror")
        XCTAssertTrue(pt?.direction == .left, "direction")
    }

    func testPushThroughBottomRight() {
        let pt = pushThrough(for: .bottomRight)
        XCTAssertTrue(pt?.action == .bottomLeft, "mirror")
        XCTAssertTrue(pt?.direction == .right, "direction")
    }

    func testPushThroughLeftTwoThirds() {
        let pt = pushThrough(for: .leftTwoThirds)
        XCTAssertTrue(pt?.action == .rightTwoThirds, "mirror")
        XCTAssertTrue(pt?.direction == .left, "direction")
    }

    func testPushThroughRightTwoThirds() {
        let pt = pushThrough(for: .rightTwoThirds)
        XCTAssertTrue(pt?.action == .leftTwoThirds, "mirror")
        XCTAssertTrue(pt?.direction == .right, "direction")
    }

    func testPushThroughMaximizeReturnsNil() {
        XCTAssertNil(pushThrough(for: .maximize))
    }

    func testPushThroughCenterReturnsNil() {
        XCTAssertNil(pushThrough(for: .center))
    }

    func testPushThroughStaticThirdsReturnNil() {
        XCTAssertNil(pushThrough(for: .firstThird))
        XCTAssertNil(pushThrough(for: .centerThird))
        XCTAssertNil(pushThrough(for: .lastThird))
    }

    // MARK: - adjacentScreen: vertical

    func testAdjacentScreenAboveReturnsUpper() {
        let result = adjacentScreen(to: screenBottom.visibleFrame, direction: .up,
                                    among: [screenBottom, screenTop])
        XCTAssertEqual(result?.visibleFrame ?? .zero, screenTop.visibleFrame, "should return upper screen")
    }

    func testAdjacentScreenBelowReturnsLower() {
        let result = adjacentScreen(to: screenTop.visibleFrame, direction: .down,
                                    among: [screenBottom, screenTop])
        XCTAssertEqual(result?.visibleFrame ?? .zero, screenBottom.visibleFrame, "should return lower screen")
    }

    func testAdjacentScreenNoScreenAboveTopmost() {
        XCTAssertNil(adjacentScreen(to: screenTop.visibleFrame, direction: .up, among: [screenBottom, screenTop]),
                     "topmost screen has no upper neighbour")
    }

    func testAdjacentScreenNoScreenBelowBottommost() {
        XCTAssertNil(adjacentScreen(to: screenBottom.visibleFrame, direction: .down, among: [screenBottom, screenTop]),
                     "bottommost screen has no lower neighbour")
    }

    // MARK: - rectsMatch

    func testRectsMatchIdentical() {
        XCTAssertTrue(rectsMatch(CGRect(x: 10, y: 20, width: 960, height: 540),
                                 CGRect(x: 10, y: 20, width: 960, height: 540)))
    }

    func testRectsMatchWithinTolerance() {
        XCTAssertTrue(rectsMatch(CGRect(x: 10, y: 20, width: 960, height: 540),
                                 CGRect(x: 11, y: 21, width: 961, height: 539), tolerance: 2))
    }

    func testRectsMatchBeyondToleranceDoNotMatch() {
        XCTAssertTrue(!rectsMatch(CGRect(x: 10, y: 20, width: 960, height: 540),
                                  CGRect(x: 14, y: 20, width: 960, height: 540), tolerance: 2))
    }

    // MARK: - Target rect on adjacent screen

    func testPushThroughLeftHalfOfBToRightHalfOfA() {
        let leftHalfB = computeTargetRect(action: .leftHalf, visibleFrame: screenB.visibleFrame,
                                          primaryScreenHeight: ph, currentAXOrigin: .zero)
        guard let pt = pushThrough(for: .leftHalf) else {
            XCTFail("pushThrough(for: .leftHalf) should not be nil"); return
        }
        let neighbor = adjacentScreen(to: screenB.visibleFrame, direction: pt.direction,
                                      among: [screenA, screenB, screenC])
        XCTAssertTrue(neighbor?.visibleFrame == screenA.visibleFrame, "adjacent screen is A")
        let pushTarget = computeTargetRect(action: pt.action, visibleFrame: screenA.visibleFrame,
                                           primaryScreenHeight: ph, currentAXOrigin: leftHalfB.origin)
        XCTAssertEqual(pushTarget.origin.x, 960, accuracy: 0.001, "x")
        XCTAssertEqual(pushTarget.origin.y, 0, accuracy: 0.001, "y")
        XCTAssertEqual(pushTarget.width, 960, accuracy: 0.001, "w")
        XCTAssertEqual(pushTarget.height, 1057, accuracy: 0.001, "h")
    }

    func testPushThroughRightHalfOfBToLeftHalfOfC() {
        guard let pt = pushThrough(for: .rightHalf) else {
            XCTFail("pushThrough(for: .rightHalf) should not be nil"); return
        }
        let neighbor = adjacentScreen(to: screenB.visibleFrame, direction: pt.direction,
                                      among: [screenB, screenC])
        XCTAssertTrue(neighbor?.visibleFrame == screenC.visibleFrame, "adjacent screen is C")
        let pushTarget = computeTargetRect(action: pt.action, visibleFrame: screenC.visibleFrame,
                                           primaryScreenHeight: ph, currentAXOrigin: .zero)
        XCTAssertEqual(pushTarget.origin.x, 3840, accuracy: 0.001, "x")
        XCTAssertEqual(pushTarget.origin.y, 0, accuracy: 0.001, "y")
        XCTAssertEqual(pushTarget.width, 960, accuracy: 0.001, "w")
        XCTAssertEqual(pushTarget.height, 1080, accuracy: 0.001, "h")
    }
}
