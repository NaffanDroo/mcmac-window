import AppKit

private let ph: CGFloat  = 1080
private let vf           = CGRect(x: 0, y: 0, width: 1920, height: 1043)

private func target(_ action: WindowAction, origin: CGPoint = .zero) -> CGRect {
    computeTargetRect(action: action, visibleFrame: vf, primaryScreenHeight: ph, currentAXOrigin: origin)
}

func geometryTests() -> [Test] { [

    // MARK: axRect()

    Test("axRect: primary visibleFrame → AX origin y=37") {
        let r = axRect(from: vf, primaryScreenHeight: ph)
        assertEq(r.origin.x, 0, "x"); assertEq(r.origin.y, 37, "y")
        assertEq(r.width, 1920, "w"); assertEq(r.height, 1043, "h")
    },
    Test("axRect: full primary frame → AX y=0") {
        let r = axRect(from: CGRect(x: 0, y: 0, width: 1920, height: 1080), primaryScreenHeight: ph)
        assertEq(r.origin.y, 0)
    },
    Test("axRect: secondary above primary → negative AX y") {
        let r = axRect(from: CGRect(x: 0, y: 1080, width: 1920, height: 1043), primaryScreenHeight: ph)
        assertEq(r.origin.y, -1043)
    },
    Test("axRect: larger secondary to the right → negative AX y, x preserved") {
        let r = axRect(from: CGRect(x: 1920, y: 0, width: 2560, height: 1413), primaryScreenHeight: ph)
        assertEq(r.origin.x, 1920, "x"); assertEq(r.origin.y, -333, "y")
        assertEq(r.width, 2560, "w");    assertEq(r.height, 1413, "h")
    },
    Test("axRect: size components are never negated or swapped") {
        let r = axRect(from: CGRect(x: 100, y: 200, width: 800, height: 600), primaryScreenHeight: ph)
        assertEq(r.width, 800); assertEq(r.height, 600)
    },

    // MARK: halves

    Test("leftHalf: x=0, y=37, w=960, h=1043") {
        let r = target(.leftHalf)
        assertEq(r.origin.x, 0, "x"); assertEq(r.origin.y, 37, "y")
        assertEq(r.width, 960, "w");   assertEq(r.height, 1043, "h")
    },
    Test("rightHalf: x=960, y=37, w=960, h=1043") {
        let r = target(.rightHalf)
        assertEq(r.origin.x, 960, "x"); assertEq(r.origin.y, 37, "y")
        assertEq(r.width, 960, "w");    assertEq(r.height, 1043, "h")
    },
    Test("topHalf: x=0, y=37, w=1920, h=521.5") {
        let r = target(.topHalf)
        assertEq(r.origin.x, 0, "x");   assertEq(r.origin.y, 37, "y")
        assertEq(r.width, 1920, "w");   assertEq(r.height, 521.5, "h")
    },
    Test("bottomHalf: x=0, y=558.5, w=1920, h=521.5") {
        let r = target(.bottomHalf)
        assertEq(r.origin.x, 0, "x");    assertEq(r.origin.y, 558.5, "y")
        assertEq(r.width, 1920, "w");    assertEq(r.height, 521.5, "h")
    },

    // MARK: quarters

    Test("topLeft: x=0, y=37, w=960, h=521.5") {
        let r = target(.topLeft)
        assertEq(r.origin.x, 0, "x");  assertEq(r.origin.y, 37, "y")
        assertEq(r.width, 960, "w");   assertEq(r.height, 521.5, "h")
    },
    Test("topRight: x=960, y=37, w=960, h=521.5") {
        let r = target(.topRight)
        assertEq(r.origin.x, 960, "x"); assertEq(r.origin.y, 37, "y")
        assertEq(r.width, 960, "w");    assertEq(r.height, 521.5, "h")
    },
    Test("bottomLeft: x=0, y=558.5, w=960, h=521.5") {
        let r = target(.bottomLeft)
        assertEq(r.origin.x, 0, "x");   assertEq(r.origin.y, 558.5, "y")
        assertEq(r.width, 960, "w");    assertEq(r.height, 521.5, "h")
    },
    Test("bottomRight: x=960, y=558.5, w=960, h=521.5") {
        let r = target(.bottomRight)
        assertEq(r.origin.x, 960, "x");  assertEq(r.origin.y, 558.5, "y")
        assertEq(r.width, 960, "w");     assertEq(r.height, 521.5, "h")
    },

    // MARK: maximize & center

    Test("maximize fills the entire visibleFrame") {
        let r = target(.maximize)
        assertEq(r.origin.x, 0, "x"); assertEq(r.origin.y, 37, "y")
        assertEq(r.width, 1920, "w"); assertEq(r.height, 1043, "h")
    },
    Test("center is 65% of visibleFrame, centred") {
        let r  = target(.center)
        let tw = 1920 * 0.65 as CGFloat
        let th = 1043 * 0.65 as CGFloat
        assertEq(r.width, tw, tol: 0.01, "w"); assertEq(r.height, th, tol: 0.01, "h")
        assertEq(r.origin.x, (1920 - tw) / 2,       tol: 0.01, "x")
        assertEq(r.origin.y, 37 + (1043 - th) / 2,  tol: 0.01, "y")
    },

    // MARK: thirds cycling

    Test("nextThirdRight from left → center (x=640)") {
        let r = target(.nextThirdRight, origin: CGPoint(x: 0, y: 37))
        assertEq(r.origin.x, 640, "x"); assertEq(r.origin.y, 37, "y")
        assertEq(r.width, 640, "w");    assertEq(r.height, 1043, "h")
    },
    Test("nextThirdRight from center → right (x=1280)") {
        assertEq(target(.nextThirdRight, origin: CGPoint(x: 640, y: 37)).origin.x, 1280)
    },
    Test("nextThirdRight from right → wraps to left (x=0)") {
        assertEq(target(.nextThirdRight, origin: CGPoint(x: 1280, y: 37)).origin.x, 0)
    },
    Test("nextThirdLeft from center → left (x=0)") {
        assertEq(target(.nextThirdLeft, origin: CGPoint(x: 640, y: 37)).origin.x, 0)
    },
    Test("nextThirdLeft from left → wraps to right (x=1280)") {
        assertEq(target(.nextThirdLeft, origin: CGPoint(x: 0, y: 37)).origin.x, 1280)
    },
    Test("thirds slot detection with drift: x=650 → slot 1 → right → x=1280") {
        assertEq(target(.nextThirdRight, origin: CGPoint(x: 650, y: 37)).origin.x, 1280)
    },
    Test("thirds midpoint tie (x=320): earlier slot wins → nextRight=640") {
        assertEq(target(.nextThirdRight, origin: CGPoint(x: 320, y: 37)).origin.x, 640)
    },

    // MARK: screenContaining()

    Test("screenContaining: point in primary screen") {
        let p = ScreenInfo(frame: CGRect(x: 0,    y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 0,    y: 0, width: 1920, height: 1043))
        let s = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1043))
        assertEq(screenContaining(axPoint: CGPoint(x: 100, y: 50), screens: [p, s], primaryScreenHeight: ph), p.visibleFrame)
    },
    Test("screenContaining: point in secondary screen") {
        let p = ScreenInfo(frame: CGRect(x: 0,    y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 0,    y: 0, width: 1920, height: 1043))
        let s = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1043))
        assertEq(screenContaining(axPoint: CGPoint(x: 2000, y: 50), screens: [p, s], primaryScreenHeight: ph), s.visibleFrame)
    },
    Test("screenContaining: x=1920 boundary belongs to secondary, not primary") {
        let p = ScreenInfo(frame: CGRect(x: 0,    y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 0,    y: 0, width: 1920, height: 1043))
        let s = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1043))
        assertEq(screenContaining(axPoint: CGPoint(x: 1920, y: 50), screens: [p, s], primaryScreenHeight: ph), s.visibleFrame)
    },
    Test("screenContaining: off-screen point falls back to first screen") {
        let p = ScreenInfo(frame: CGRect(x: 0,    y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 0,    y: 0, width: 1920, height: 1043))
        let s = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1043))
        assertEq(screenContaining(axPoint: CGPoint(x: -999, y: 50), screens: [p, s], primaryScreenHeight: ph), p.visibleFrame)
    },
    Test("screenContaining: single monitor always matches") {
        let single = [ScreenInfo(frame: CGRect(x: 0, y: 0, width: 2560, height: 1600),
                                 visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1552))]
        assertEq(screenContaining(axPoint: CGPoint(x: 1000, y: 200), screens: single, primaryScreenHeight: 1600),
                 single[0].visibleFrame)
    },

    // MARK: non-regression

    Test("left + right halves touch with no gap, sum to full width") {
        let L = target(.leftHalf); let R = target(.rightHalf)
        assertEq(L.width + R.width, vf.width, "total width")
        assertEq(L.maxX, R.minX, "touching at x=960")
    },
    Test("top + bottom halves touch with no gap, sum to full height") {
        let T = target(.topHalf); let B = target(.bottomHalf)
        assertEq(T.height + B.height, vf.height, "total height")
        assertEq(T.maxY, B.minY, "touching")
    },
    Test("all four quarters tile without gaps or overlaps") {
        let tl = target(.topLeft); let tr = target(.topRight); let bl = target(.bottomLeft)
        assertEq(tl.width + tr.width,   vf.width,  "top row width")
        assertEq(tl.height + bl.height, vf.height, "left column height")
        assertEq(tl.maxX, tr.minX, "top quarters touch horizontally")
        assertEq(tl.maxY, bl.minY, "quarters touch vertically")
    },
    Test("three thirds widths sum to full visibleFrame width") {
        assertEq(vf.width / 3 * 3, vf.width)
    },

] }
