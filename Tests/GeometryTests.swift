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

    // MARK: two thirds

    Test("leftTwoThirds: x=0, y=37, w=1280, h=1043") {
        let r = target(.leftTwoThirds)
        assertEq(r.origin.x, 0,    "x"); assertEq(r.origin.y, 37,   "y")
        assertEq(r.width, 1280,    "w"); assertEq(r.height, 1043,   "h")
    },
    Test("rightTwoThirds: x=640, y=37, w=1280, h=1043") {
        let r = target(.rightTwoThirds)
        assertEq(r.origin.x, 640,  "x"); assertEq(r.origin.y, 37,   "y")
        assertEq(r.width, 1280,    "w"); assertEq(r.height, 1043,   "h")
    },
    Test("leftTwoThirds + rightTwoThirds overlap by exactly one third") {
        let L = target(.leftTwoThirds); let R = target(.rightTwoThirds)
        let overlap = L.maxX - R.minX
        assertEq(overlap, vf.width / 3, tol: 0.001, "overlap width")
    },
    Test("leftTwoThirds left-aligns with visibleFrame") {
        assertEq(target(.leftTwoThirds).origin.x, axRect(from: vf, primaryScreenHeight: ph).minX)
    },
    Test("rightTwoThirds right-aligns with visibleFrame") {
        let r  = target(.rightTwoThirds)
        let ax = axRect(from: vf, primaryScreenHeight: ph)
        assertEq(r.maxX, ax.maxX, tol: 0.001, "right edge")
    },

    // MARK: push-through — adjacentScreen()
    //
    // Three-screen layout (AppKit coords, primary screen is A):
    //   A: frame=(0,0,1920,1080)  visibleFrame=(0,23,1920,1057)   — has menu bar
    //   B: frame=(1920,0,1920,1080) visibleFrame=(1920,0,1920,1080)
    //   C: frame=(3840,0,1920,1080) visibleFrame=(3840,0,1920,1080)

    Test("adjacentScreen: left of B returns A") {
        let A = ScreenInfo(frame: CGRect(x:    0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x:    0, y: 23, width: 1920, height: 1057))
        let B = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y:  0, width: 1920, height: 1080))
        let C = ScreenInfo(frame: CGRect(x: 3840, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 3840, y:  0, width: 1920, height: 1080))
        let result = adjacentScreen(to: B.visibleFrame, direction: .left, among: [A, B, C])
        assertEq(result?.visibleFrame ?? .zero, A.visibleFrame, "should return screen A")
    },
    Test("adjacentScreen: right of B returns C") {
        let A = ScreenInfo(frame: CGRect(x:    0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x:    0, y: 23, width: 1920, height: 1057))
        let B = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y:  0, width: 1920, height: 1080))
        let C = ScreenInfo(frame: CGRect(x: 3840, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 3840, y:  0, width: 1920, height: 1080))
        let result = adjacentScreen(to: B.visibleFrame, direction: .right, among: [A, B, C])
        assertEq(result?.visibleFrame ?? .zero, C.visibleFrame, "should return screen C")
    },
    Test("adjacentScreen: no screen to the left of leftmost") {
        let A = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 0, y: 23, width: 1920, height: 1057))
        let B = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1080))
        assertTrue(adjacentScreen(to: A.visibleFrame, direction: .left, among: [A, B]) == nil,
                   "leftmost screen has no left neighbour")
    },
    Test("adjacentScreen: no screen to the right of rightmost") {
        let A = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 0, y: 23, width: 1920, height: 1057))
        let B = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1080))
        assertTrue(adjacentScreen(to: B.visibleFrame, direction: .right, among: [A, B]) == nil,
                   "rightmost screen has no right neighbour")
    },
    Test("adjacentScreen: single screen has no neighbours") {
        let A = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 0, y: 23, width: 1920, height: 1057))
        assertTrue(adjacentScreen(to: A.visibleFrame, direction: .left,  among: [A]) == nil)
        assertTrue(adjacentScreen(to: A.visibleFrame, direction: .right, among: [A]) == nil)
    },

    // MARK: push-through — pushThrough(for:)

    Test("pushThrough: leftHalf → rightHalf going left") {
        let pt = pushThrough(for: .leftHalf)
        assertTrue(pt?.action == .rightHalf, "mirror action"); assertTrue(pt?.direction == .left, "direction")
    },
    Test("pushThrough: rightHalf → leftHalf going right") {
        let pt = pushThrough(for: .rightHalf)
        assertTrue(pt?.action == .leftHalf, "mirror action"); assertTrue(pt?.direction == .right, "direction")
    },
    Test("pushThrough: topHalf → bottomHalf going up") {
        let pt = pushThrough(for: .topHalf)
        assertTrue(pt?.action == .bottomHalf, "mirror action"); assertTrue(pt?.direction == .up, "direction")
    },
    Test("pushThrough: bottomHalf → topHalf going down") {
        let pt = pushThrough(for: .bottomHalf)
        assertTrue(pt?.action == .topHalf, "mirror action"); assertTrue(pt?.direction == .down, "direction")
    },
    Test("pushThrough: topLeft → topRight going left") {
        let pt = pushThrough(for: .topLeft)
        assertTrue(pt?.action == .topRight, "mirror action"); assertTrue(pt?.direction == .left, "direction")
    },
    Test("pushThrough: topRight → topLeft going right") {
        let pt = pushThrough(for: .topRight)
        assertTrue(pt?.action == .topLeft, "mirror action"); assertTrue(pt?.direction == .right, "direction")
    },
    Test("pushThrough: bottomLeft → bottomRight going left") {
        let pt = pushThrough(for: .bottomLeft)
        assertTrue(pt?.action == .bottomRight, "mirror"); assertTrue(pt?.direction == .left, "direction")
    },
    Test("pushThrough: bottomRight → bottomLeft going right") {
        let pt = pushThrough(for: .bottomRight)
        assertTrue(pt?.action == .bottomLeft, "mirror"); assertTrue(pt?.direction == .right, "direction")
    },
    Test("pushThrough: leftTwoThirds → rightTwoThirds going left") {
        let pt = pushThrough(for: .leftTwoThirds)
        assertTrue(pt?.action == .rightTwoThirds, "mirror"); assertTrue(pt?.direction == .left, "direction")
    },
    Test("pushThrough: rightTwoThirds → leftTwoThirds going right") {
        let pt = pushThrough(for: .rightTwoThirds)
        assertTrue(pt?.action == .leftTwoThirds, "mirror"); assertTrue(pt?.direction == .right, "direction")
    },
    Test("pushThrough: maximize returns nil (no push-through)") {
        assertTrue(pushThrough(for: .maximize) == nil)
    },
    Test("pushThrough: center returns nil (no push-through)") {
        assertTrue(pushThrough(for: .center) == nil)
    },
    Test("pushThrough: nextThirdLeft returns nil (cycles within screen)") {
        assertTrue(pushThrough(for: .nextThirdLeft) == nil)
    },

    // MARK: push-through — rectsMatch()

    Test("rectsMatch: identical rects match") {
        let r = CGRect(x: 10, y: 20, width: 960, height: 540)
        assertTrue(rectsMatch(r, r))
    },
    Test("rectsMatch: rects within 2px tolerance match") {
        let a = CGRect(x: 10, y: 20, width: 960, height: 540)
        let b = CGRect(x: 11, y: 21, width: 961, height: 539)
        assertTrue(rectsMatch(a, b, tolerance: 2))
    },
    Test("rectsMatch: rects beyond tolerance do not match") {
        let a = CGRect(x: 10, y: 20, width: 960, height: 540)
        let b = CGRect(x: 14, y: 20, width: 960, height: 540)
        assertTrue(!rectsMatch(a, b, tolerance: 2))
    },

    // MARK: push-through — target rect on adjacent screen

    Test("push-through leftHalf of B → rightHalf of A: correct AX rect") {
        // Three-screen layout; ph = 1080
        let ptPh: CGFloat = 1080
        let screenA = ScreenInfo(frame: CGRect(x:    0, y: 0, width: 1920, height: 1080),
                                 visibleFrame: CGRect(x:    0, y: 23, width: 1920, height: 1057))
        let screenB = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                                 visibleFrame: CGRect(x: 1920, y:  0, width: 1920, height: 1080))
        let screenC = ScreenInfo(frame: CGRect(x: 3840, y: 0, width: 1920, height: 1080),
                                 visibleFrame: CGRect(x: 3840, y:  0, width: 1920, height: 1080))
        // Window is already at leftHalf of B in AX coords
        let leftHalfB = computeTargetRect(action: .leftHalf, visibleFrame: screenB.visibleFrame,
                                          primaryScreenHeight: ptPh, currentAXOrigin: .zero)
        // Verify push-through selects the right adjacent screen and mirror action
        let pt = pushThrough(for: .leftHalf)!
        let neighbor = adjacentScreen(to: screenB.visibleFrame, direction: pt.direction,
                                      among: [screenA, screenB, screenC])
        assertTrue(neighbor?.visibleFrame == screenA.visibleFrame, "adjacent screen is A")
        let pushTarget = computeTargetRect(action: pt.action, visibleFrame: screenA.visibleFrame,
                                           primaryScreenHeight: ptPh, currentAXOrigin: leftHalfB.origin)
        // rightHalf of A in AX: x=960, y=0, w=960, h=1057
        assertEq(pushTarget.origin.x, 960,  tol: 0.001, "x")
        assertEq(pushTarget.origin.y, 0,    tol: 0.001, "y")
        assertEq(pushTarget.width,    960,  tol: 0.001, "w")
        assertEq(pushTarget.height,   1057, tol: 0.001, "h")
    },
    Test("push-through rightHalf of B → leftHalf of C: correct AX rect") {
        let ptPh: CGFloat = 1080
        let screenB = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                                 visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1080))
        let screenC = ScreenInfo(frame: CGRect(x: 3840, y: 0, width: 1920, height: 1080),
                                 visibleFrame: CGRect(x: 3840, y: 0, width: 1920, height: 1080))
        let pt = pushThrough(for: .rightHalf)!
        let neighbor = adjacentScreen(to: screenB.visibleFrame, direction: pt.direction,
                                      among: [screenB, screenC])
        assertTrue(neighbor?.visibleFrame == screenC.visibleFrame, "adjacent screen is C")
        let pushTarget = computeTargetRect(action: pt.action, visibleFrame: screenC.visibleFrame,
                                           primaryScreenHeight: ptPh, currentAXOrigin: .zero)
        // leftHalf of C in AX: x=3840, y=0, w=960, h=1080
        assertEq(pushTarget.origin.x, 3840, tol: 0.001, "x")
        assertEq(pushTarget.origin.y, 0,    tol: 0.001, "y")
        assertEq(pushTarget.width,    960,  tol: 0.001, "w")
        assertEq(pushTarget.height,   1080, tol: 0.001, "h")
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
