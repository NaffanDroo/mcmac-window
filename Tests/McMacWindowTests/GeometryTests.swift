import XCTest
@testable import McMacWindowCore

let ph: CGFloat  = 1080
let vf           = CGRect(x: 0, y: 0, width: 1920, height: 1043)

func target(_ action: WindowAction, origin: CGPoint = .zero) -> CGRect {
    computeTargetRect(action: action, visibleFrame: vf, primaryScreenHeight: ph, currentAXOrigin: origin)
}

// Non-primary screen: x=1920, no menu bar, different resolution.
let secVF = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
func secTarget(_ a: WindowAction) -> CGRect {
    computeTargetRect(action: a, visibleFrame: secVF, primaryScreenHeight: 1440, currentAXOrigin: CGPoint(x: 1920, y: 0))
}

class GeometryTests: XCTestCase {

    // MARK: - axRect

    func testAxRectPrimaryVisibleFrame() {
        let r = axRect(from: vf, primaryScreenHeight: ph)
        XCTAssertEqual(r.origin.x, 0, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 37, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 1920, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 1043, accuracy: 0.001, "h")
    }

    func testAxRectFullPrimaryFrame() {
        let r = axRect(from: CGRect(x: 0, y: 0, width: 1920, height: 1080), primaryScreenHeight: ph)
        XCTAssertEqual(r.origin.y, 0, accuracy: 0.001)
    }

    func testAxRectSecondaryAbovePrimary() {
        let r = axRect(from: CGRect(x: 0, y: 1080, width: 1920, height: 1043), primaryScreenHeight: ph)
        XCTAssertEqual(r.origin.y, -1043, accuracy: 0.001)
    }

    func testAxRectLargerSecondaryToTheRight() {
        let r = axRect(from: CGRect(x: 1920, y: 0, width: 2560, height: 1413), primaryScreenHeight: ph)
        XCTAssertEqual(r.origin.x, 1920, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, -333, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 2560, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 1413, accuracy: 0.001, "h")
    }

    func testAxRectSizeComponentsNeverNegated() {
        let r = axRect(from: CGRect(x: 100, y: 200, width: 800, height: 600), primaryScreenHeight: ph)
        XCTAssertEqual(r.width, 800, accuracy: 0.001)
        XCTAssertEqual(r.height, 600, accuracy: 0.001)
    }

    // MARK: - Snap actions: halves

    func testLeftHalf() {
        let r = target(.leftHalf)
        XCTAssertEqual(r.origin.x, 0, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 37, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 960, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 1043, accuracy: 0.001, "h")
    }

    func testRightHalf() {
        let r = target(.rightHalf)
        XCTAssertEqual(r.origin.x, 960, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 37, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 960, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 1043, accuracy: 0.001, "h")
    }

    func testTopHalf() {
        let r = target(.topHalf)
        XCTAssertEqual(r.origin.x, 0, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 37, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 1920, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 521.5, accuracy: 0.001, "h")
    }

    func testBottomHalf() {
        let r = target(.bottomHalf)
        XCTAssertEqual(r.origin.x, 0, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 558.5, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 1920, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 521.5, accuracy: 0.001, "h")
    }

    // MARK: - Snap actions: quarters

    func testTopLeft() {
        let r = target(.topLeft)
        XCTAssertEqual(r.origin.x, 0, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 37, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 960, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 521.5, accuracy: 0.001, "h")
    }

    func testTopRight() {
        let r = target(.topRight)
        XCTAssertEqual(r.origin.x, 960, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 37, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 960, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 521.5, accuracy: 0.001, "h")
    }

    func testBottomLeft() {
        let r = target(.bottomLeft)
        XCTAssertEqual(r.origin.x, 0, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 558.5, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 960, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 521.5, accuracy: 0.001, "h")
    }

    func testBottomRight() {
        let r = target(.bottomRight)
        XCTAssertEqual(r.origin.x, 960, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 558.5, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 960, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 521.5, accuracy: 0.001, "h")
    }

    // MARK: - Maximize & center

    func testMaximize() {
        let r = target(.maximize)
        XCTAssertEqual(r.origin.x, 0, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 37, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 1920, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 1043, accuracy: 0.001, "h")
    }

    func testCenter() {
        let r  = target(.center)
        let tw = 1920 * 0.65 as CGFloat
        let th = 1043 * 0.65 as CGFloat
        XCTAssertEqual(r.width, tw, accuracy: 0.01, "w")
        XCTAssertEqual(r.height, th, accuracy: 0.01, "h")
        XCTAssertEqual(r.origin.x, (1920 - tw) / 2, accuracy: 0.01, "x")
        XCTAssertEqual(r.origin.y, 37 + (1043 - th) / 2, accuracy: 0.01, "y")
    }

    // MARK: - Thirds

    func testFirstThird() {
        let r = target(.firstThird)
        XCTAssertEqual(r.origin.x, 0, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 37, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 640, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 1043, accuracy: 0.001, "h")
    }

    func testCenterThird() {
        let r = target(.centerThird)
        XCTAssertEqual(r.origin.x, 640, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 37, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 640, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 1043, accuracy: 0.001, "h")
    }

    func testLastThird() {
        let r = target(.lastThird)
        XCTAssertEqual(r.origin.x, 1280, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 37, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 640, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 1043, accuracy: 0.001, "h")
    }

    // MARK: - Two thirds

    func testLeftTwoThirds() {
        let r = target(.leftTwoThirds)
        XCTAssertEqual(r.origin.x, 0, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 37, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 1280, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 1043, accuracy: 0.001, "h")
    }

    func testRightTwoThirds() {
        let r = target(.rightTwoThirds)
        XCTAssertEqual(r.origin.x, 640, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 37, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 1280, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 1043, accuracy: 0.001, "h")
    }

    func testLeftAndRightTwoThirdsOverlapByOneThird() {
        let L = target(.leftTwoThirds)
        let R = target(.rightTwoThirds)
        XCTAssertEqual(L.maxX - R.minX, vf.width / 3, accuracy: 0.001, "overlap width")
    }

    func testLeftTwoThirdsLeftAligns() {
        XCTAssertEqual(target(.leftTwoThirds).origin.x, axRect(from: vf, primaryScreenHeight: ph).minX, accuracy: 0.001)
    }

    func testRightTwoThirdsRightAligns() {
        let r  = target(.rightTwoThirds)
        let ax = axRect(from: vf, primaryScreenHeight: ph)
        XCTAssertEqual(r.maxX, ax.maxX, accuracy: 0.001, "right edge")
    }

    // MARK: - screenContaining

    func testScreenContainingPointInPrimary() {
        let p = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1043))
        let s = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1043))
        XCTAssertEqual(screenContaining(axPoint: CGPoint(x: 100, y: 50), screens: [p, s], primaryScreenHeight: ph), p.visibleFrame)
    }

    func testScreenContainingPointInSecondary() {
        let p = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1043))
        let s = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1043))
        XCTAssertEqual(screenContaining(axPoint: CGPoint(x: 2000, y: 50), screens: [p, s], primaryScreenHeight: ph), s.visibleFrame)
    }

    func testScreenContainingBoundaryBelongsToSecondary() {
        let p = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1043))
        let s = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1043))
        XCTAssertEqual(screenContaining(axPoint: CGPoint(x: 1920, y: 50), screens: [p, s], primaryScreenHeight: ph), s.visibleFrame)
    }

    func testScreenContainingOffScreenFallsBackToFirst() {
        let p = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1043))
        let s = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1043))
        XCTAssertEqual(screenContaining(axPoint: CGPoint(x: -999, y: 50), screens: [p, s], primaryScreenHeight: ph), p.visibleFrame)
    }

    func testScreenContainingSingleMonitorAlwaysMatches() {
        let single = [ScreenInfo(frame: CGRect(x: 0, y: 0, width: 2560, height: 1600),
                                 visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1552))]
        XCTAssertEqual(screenContaining(axPoint: CGPoint(x: 1000, y: 200), screens: single, primaryScreenHeight: 1600),
                       single[0].visibleFrame)
    }

    // MARK: - Non-regression

    func testLeftRightHalvesTouchNoGap() {
        let L = target(.leftHalf)
        let R = target(.rightHalf)
        XCTAssertEqual(L.width + R.width, vf.width, accuracy: 0.001, "total width")
        XCTAssertEqual(L.maxX, R.minX, accuracy: 0.001, "touching at x=960")
    }

    func testTopBottomHalvesTouchNoGap() {
        let T = target(.topHalf)
        let B = target(.bottomHalf)
        XCTAssertEqual(T.height + B.height, vf.height, accuracy: 0.001, "total height")
        XCTAssertEqual(T.maxY, B.minY, accuracy: 0.001, "touching")
    }

    func testFourQuartersTileWithoutGaps() {
        let tl = target(.topLeft)
        let tr = target(.topRight)
        let bl = target(.bottomLeft)
        XCTAssertEqual(tl.width + tr.width, vf.width, accuracy: 0.001, "top row width")
        XCTAssertEqual(tl.height + bl.height, vf.height, accuracy: 0.001, "left column height")
        XCTAssertEqual(tl.maxX, tr.minX, accuracy: 0.001, "top quarters touch horizontally")
        XCTAssertEqual(tl.maxY, bl.minY, accuracy: 0.001, "quarters touch vertically")
    }

    func testThreeStaticThirdsTileWithoutGaps() {
        let f = target(.firstThird)
        let c = target(.centerThird)
        let l = target(.lastThird)
        XCTAssertEqual(f.width + c.width + l.width, vf.width, accuracy: 0.001, "total width")
        XCTAssertEqual(f.maxX, c.minX, accuracy: 0.001, "first->center touch")
        XCTAssertEqual(c.maxX, l.minX, accuracy: 0.001, "center->last touch")
    }

    // MARK: - Non-primary screen

    func testSecondaryLeftHalf() {
        let r = secTarget(.leftHalf)
        XCTAssertEqual(r.origin.x, 1920, accuracy: 0.001, "x")
        XCTAssertEqual(r.width, 1280, accuracy: 0.001, "w")
        XCTAssertEqual(r.origin.y, 0, accuracy: 0.001, "y")
        XCTAssertEqual(r.height, 1440, accuracy: 0.001, "h")
    }

    func testSecondaryRightHalf() {
        let r = secTarget(.rightHalf)
        XCTAssertEqual(r.origin.x, 1920 + 1280, accuracy: 0.001, "x")
        XCTAssertEqual(r.width, 1280, accuracy: 0.001, "w")
    }

    func testSecondaryMaximize() {
        let r = secTarget(.maximize)
        XCTAssertEqual(r.origin.x, 1920, accuracy: 0.001, "x")
        XCTAssertEqual(r.origin.y, 0, accuracy: 0.001, "y")
        XCTAssertEqual(r.width, 2560, accuracy: 0.001, "w")
        XCTAssertEqual(r.height, 1440, accuracy: 0.001, "h")
    }

    func testSecondaryQuarters() {
        let tl = secTarget(.topLeft)
        XCTAssertEqual(tl.origin.x, 1920, accuracy: 0.001, "tl.x")
        XCTAssertEqual(tl.origin.y, 0, accuracy: 0.001, "tl.y")
        XCTAssertEqual(tl.width, 1280, accuracy: 0.001, "tl.w")
        XCTAssertEqual(tl.height, 720, accuracy: 0.001, "tl.h")
        let br = secTarget(.bottomRight)
        XCTAssertEqual(br.origin.x, 1920 + 1280, accuracy: 0.001, "br.x")
        XCTAssertEqual(br.origin.y, 720, accuracy: 0.001, "br.y")
        XCTAssertEqual(br.width, 1280, accuracy: 0.001, "br.w")
        XCTAssertEqual(br.height, 720, accuracy: 0.001, "br.h")
    }

    func testSecondaryHalvesAndQuartersTile() {
        let L = secTarget(.leftHalf)
        let R = secTarget(.rightHalf)
        XCTAssertEqual(L.width + R.width, secVF.width, accuracy: 0.001, "halves total width")
        XCTAssertEqual(L.maxX, R.minX, accuracy: 0.001, "halves touching")
        let tl = secTarget(.topLeft)
        let tr = secTarget(.topRight)
        let bl = secTarget(.bottomLeft)
        XCTAssertEqual(tl.width + tr.width, secVF.width, accuracy: 0.001, "top row width")
        XCTAssertEqual(tl.height + bl.height, secVF.height, accuracy: 0.001, "left column height")
    }
}
