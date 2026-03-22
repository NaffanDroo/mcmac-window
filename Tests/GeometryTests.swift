import AppKit

private let ph: CGFloat  = 1080
private let vf           = CGRect(x: 0, y: 0, width: 1920, height: 1043)

private func target(_ action: WindowAction, origin: CGPoint = .zero) -> CGRect {
    computeTargetRect(action: action, visibleFrame: vf, primaryScreenHeight: ph, currentAXOrigin: origin)
}

// MARK: - Sub-suites (each well under the 300-line body limit)

private func axRectTests() -> [Test] { [
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
] }

private func snapActionTests() -> [Test] { [
    // halves
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
        assertEq(r.origin.x, 0, "x");  assertEq(r.origin.y, 37, "y")
        assertEq(r.width, 1920, "w");  assertEq(r.height, 521.5, "h")
    },
    Test("bottomHalf: x=0, y=558.5, w=1920, h=521.5") {
        let r = target(.bottomHalf)
        assertEq(r.origin.x, 0, "x");   assertEq(r.origin.y, 558.5, "y")
        assertEq(r.width, 1920, "w");   assertEq(r.height, 521.5, "h")
    },
    // quarters
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
    // maximize & center
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
    // thirds (static — matches Rectangle's D/F/G shortcuts)
    Test("firstThird: x=0, y=37, w=640, h=1043") {
        let r = target(.firstThird)
        assertEq(r.origin.x, 0,   "x"); assertEq(r.origin.y, 37,   "y")
        assertEq(r.width, 640,    "w"); assertEq(r.height, 1043,   "h")
    },
    Test("centerThird: x=640, y=37, w=640, h=1043") {
        let r = target(.centerThird)
        assertEq(r.origin.x, 640, "x"); assertEq(r.origin.y, 37,   "y")
        assertEq(r.width, 640,    "w"); assertEq(r.height, 1043,   "h")
    },
    Test("lastThird: x=1280, y=37, w=640, h=1043") {
        let r = target(.lastThird)
        assertEq(r.origin.x, 1280,"x"); assertEq(r.origin.y, 37,   "y")
        assertEq(r.width, 640,    "w"); assertEq(r.height, 1043,   "h")
    },
    // two thirds
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
        assertEq(L.maxX - R.minX, vf.width / 3, tol: 0.001, "overlap width")
    },
    Test("leftTwoThirds left-aligns with visibleFrame") {
        assertEq(target(.leftTwoThirds).origin.x, axRect(from: vf, primaryScreenHeight: ph).minX)
    },
    Test("rightTwoThirds right-aligns with visibleFrame") {
        let r  = target(.rightTwoThirds)
        let ax = axRect(from: vf, primaryScreenHeight: ph)
        assertEq(r.maxX, ax.maxX, tol: 0.001, "right edge")
    },
] }

private func screenContainingTests() -> [Test] { [
    Test("screenContaining: point in primary screen") {
        let p = ScreenInfo(frame: CGRect(x:    0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x:    0, y: 0, width: 1920, height: 1043))
        let s = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1043))
        assertEq(screenContaining(axPoint: CGPoint(x: 100, y: 50), screens: [p, s], primaryScreenHeight: ph), p.visibleFrame)
    },
    Test("screenContaining: point in secondary screen") {
        let p = ScreenInfo(frame: CGRect(x:    0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x:    0, y: 0, width: 1920, height: 1043))
        let s = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1043))
        assertEq(screenContaining(axPoint: CGPoint(x: 2000, y: 50), screens: [p, s], primaryScreenHeight: ph), s.visibleFrame)
    },
    Test("screenContaining: x=1920 boundary belongs to secondary, not primary") {
        let p = ScreenInfo(frame: CGRect(x:    0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x:    0, y: 0, width: 1920, height: 1043))
        let s = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x: 1920, y: 0, width: 1920, height: 1043))
        assertEq(screenContaining(axPoint: CGPoint(x: 1920, y: 50), screens: [p, s], primaryScreenHeight: ph), s.visibleFrame)
    },
    Test("screenContaining: off-screen point falls back to first screen") {
        let p = ScreenInfo(frame: CGRect(x:    0, y: 0, width: 1920, height: 1080),
                           visibleFrame: CGRect(x:    0, y: 0, width: 1920, height: 1043))
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
] }

// Shared screen layouts for push-through / adjacentScreen tests (AppKit coords).
// Horizontal: A (primary, has menu bar) | B | C
private let screenA = ScreenInfo(frame: CGRect(x:    0, y: 0, width: 1920, height: 1080),
                                 visibleFrame: CGRect(x:    0, y: 23, width: 1920, height: 1057))
private let screenB = ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080),
                                 visibleFrame: CGRect(x: 1920, y:  0, width: 1920, height: 1080))
private let screenC = ScreenInfo(frame: CGRect(x: 3840, y: 0, width: 1920, height: 1080),
                                 visibleFrame: CGRect(x: 3840, y:  0, width: 1920, height: 1080))
// Vertical: bottom (primary) | top
private let screenBottom = ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                      visibleFrame: CGRect(x: 0, y: 23, width: 1920, height: 1057))
private let screenTop    = ScreenInfo(frame: CGRect(x: 0, y: 1080, width: 1920, height: 1080),
                                      visibleFrame: CGRect(x: 0, y: 1080, width: 1920, height: 1080))

private func pushThroughTests() -> [Test] { [
    // adjacentScreen() — horizontal
    Test("adjacentScreen: left of B returns A") {
        assertEq(adjacentScreen(to: screenB.visibleFrame, direction: .left, among: [screenA, screenB, screenC])?.visibleFrame ?? .zero,
                 screenA.visibleFrame, "should return screen A")
    },
    Test("adjacentScreen: right of B returns C") {
        assertEq(adjacentScreen(to: screenB.visibleFrame, direction: .right, among: [screenA, screenB, screenC])?.visibleFrame ?? .zero,
                 screenC.visibleFrame, "should return screen C")
    },
    Test("adjacentScreen: no screen to the left of leftmost") {
        assertTrue(adjacentScreen(to: screenA.visibleFrame, direction: .left, among: [screenA, screenB]) == nil,
                   "leftmost screen has no left neighbour")
    },
    Test("adjacentScreen: no screen to the right of rightmost") {
        assertTrue(adjacentScreen(to: screenB.visibleFrame, direction: .right, among: [screenA, screenB]) == nil,
                   "rightmost screen has no right neighbour")
    },
    Test("adjacentScreen: single screen has no neighbours") {
        assertTrue(adjacentScreen(to: screenA.visibleFrame, direction: .left,  among: [screenA]) == nil)
        assertTrue(adjacentScreen(to: screenA.visibleFrame, direction: .right, among: [screenA]) == nil)
    },
    // pushThrough(for:)
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
    Test("pushThrough: firstThird returns nil (no push-through for static thirds)") {
        assertTrue(pushThrough(for: .firstThird) == nil)
        assertTrue(pushThrough(for: .centerThird) == nil)
        assertTrue(pushThrough(for: .lastThird) == nil)
    },
    // adjacentScreen: vertical stacking
    Test("adjacentScreen: above returns upper screen") {
        assertEq(adjacentScreen(to: screenBottom.visibleFrame, direction: .up, among: [screenBottom, screenTop])?.visibleFrame ?? .zero,
                 screenTop.visibleFrame, "should return upper screen")
    },
    Test("adjacentScreen: below returns lower screen") {
        assertEq(adjacentScreen(to: screenTop.visibleFrame, direction: .down, among: [screenBottom, screenTop])?.visibleFrame ?? .zero,
                 screenBottom.visibleFrame, "should return lower screen")
    },
    Test("adjacentScreen: no screen above topmost") {
        assertTrue(adjacentScreen(to: screenTop.visibleFrame, direction: .up, among: [screenBottom, screenTop]) == nil,
                   "topmost screen has no upper neighbour")
    },
    Test("adjacentScreen: no screen below bottommost") {
        assertTrue(adjacentScreen(to: screenBottom.visibleFrame, direction: .down, among: [screenBottom, screenTop]) == nil,
                   "bottommost screen has no lower neighbour")
    },
    // rectsMatch()
    Test("rectsMatch: identical rects match") {
        assertTrue(rectsMatch(CGRect(x: 10, y: 20, width: 960, height: 540),
                              CGRect(x: 10, y: 20, width: 960, height: 540)))
    },
    Test("rectsMatch: rects within 2px tolerance match") {
        assertTrue(rectsMatch(CGRect(x: 10, y: 20, width: 960, height: 540),
                              CGRect(x: 11, y: 21, width: 961, height: 539), tolerance: 2))
    },
    Test("rectsMatch: rects beyond tolerance do not match") {
        assertTrue(!rectsMatch(CGRect(x: 10, y: 20, width: 960, height: 540),
                               CGRect(x: 14, y: 20, width: 960, height: 540), tolerance: 2))
    },
    // Target rect on adjacent screen
    Test("push-through leftHalf of B → rightHalf of A: correct AX rect") {
        let leftHalfB = computeTargetRect(action: .leftHalf, visibleFrame: screenB.visibleFrame,
                                          primaryScreenHeight: ph, currentAXOrigin: .zero)
        guard let pt = pushThrough(for: .leftHalf) else {
            assertTrue(false, "pushThrough(for: .leftHalf) should not be nil"); return
        }
        let neighbor = adjacentScreen(to: screenB.visibleFrame, direction: pt.direction,
                                      among: [screenA, screenB, screenC])
        assertTrue(neighbor?.visibleFrame == screenA.visibleFrame, "adjacent screen is A")
        let pushTarget = computeTargetRect(action: pt.action, visibleFrame: screenA.visibleFrame,
                                           primaryScreenHeight: ph, currentAXOrigin: leftHalfB.origin)
        assertEq(pushTarget.origin.x, 960,  tol: 0.001, "x")
        assertEq(pushTarget.origin.y, 0,    tol: 0.001, "y")
        assertEq(pushTarget.width,    960,  tol: 0.001, "w")
        assertEq(pushTarget.height,   1057, tol: 0.001, "h")
    },
    Test("push-through rightHalf of B → leftHalf of C: correct AX rect") {
        guard let pt = pushThrough(for: .rightHalf) else {
            assertTrue(false, "pushThrough(for: .rightHalf) should not be nil"); return
        }
        let neighbor = adjacentScreen(to: screenB.visibleFrame, direction: pt.direction,
                                      among: [screenB, screenC])
        assertTrue(neighbor?.visibleFrame == screenC.visibleFrame, "adjacent screen is C")
        let pushTarget = computeTargetRect(action: pt.action, visibleFrame: screenC.visibleFrame,
                                           primaryScreenHeight: ph, currentAXOrigin: .zero)
        assertEq(pushTarget.origin.x, 3840, tol: 0.001, "x")
        assertEq(pushTarget.origin.y, 0,    tol: 0.001, "y")
        assertEq(pushTarget.width,    960,  tol: 0.001, "w")
        assertEq(pushTarget.height,   1080, tol: 0.001, "h")
    },
] }

private func nonRegressionTests() -> [Test] { [
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
    Test("three static thirds tile without gaps or overlaps") {
        let f = target(.firstThird); let c = target(.centerThird); let l = target(.lastThird)
        assertEq(f.width + c.width + l.width, vf.width, "total width")
        assertEq(f.maxX, c.minX, "first→center touch"); assertEq(c.maxX, l.minX, "center→last touch")
    },
] }

// Non-primary screen: x=1920, no menu bar, different resolution.
private let secVF = CGRect(x: 1920, y: 0, width: 2560, height: 1440)
private func secTarget(_ a: WindowAction) -> CGRect {
    computeTargetRect(action: a, visibleFrame: secVF, primaryScreenHeight: 1440, currentAXOrigin: CGPoint(x: 1920, y: 0))
}

private func nonPrimaryScreenTests() -> [Test] { [
    Test("secondary: leftHalf x starts at screen origin") {
        let r = secTarget(.leftHalf)
        assertEq(r.origin.x, 1920, "x"); assertEq(r.width, 1280, "w")
        assertEq(r.origin.y, 0, "y");    assertEq(r.height, 1440, "h")
    },
    Test("secondary: rightHalf x offset by half screen width") {
        let r = secTarget(.rightHalf)
        assertEq(r.origin.x, 1920 + 1280, "x"); assertEq(r.width, 1280, "w")
    },
    Test("secondary: maximize fills entire secondary visibleFrame") {
        let r = secTarget(.maximize)
        assertEq(r.origin.x, 1920, "x"); assertEq(r.origin.y, 0, "y")
        assertEq(r.width, 2560, "w");    assertEq(r.height, 1440, "h")
    },
    Test("secondary: topLeft and bottomRight quarters positioned correctly") {
        let tl = secTarget(.topLeft)
        assertEq(tl.origin.x, 1920, "tl.x"); assertEq(tl.origin.y, 0, "tl.y")
        assertEq(tl.width, 1280, "tl.w");    assertEq(tl.height, 720, "tl.h")
        let br = secTarget(.bottomRight)
        assertEq(br.origin.x, 1920 + 1280, "br.x"); assertEq(br.origin.y, 720, "br.y")
        assertEq(br.width, 1280, "br.w");            assertEq(br.height, 720, "br.h")
    },
    Test("secondary: halves and quarters tile without gaps") {
        let L = secTarget(.leftHalf); let R = secTarget(.rightHalf)
        assertEq(L.width + R.width, secVF.width, "halves total width")
        assertEq(L.maxX, R.minX, "halves touching")
        let tl = secTarget(.topLeft); let tr = secTarget(.topRight); let bl = secTarget(.bottomLeft)
        assertEq(tl.width + tr.width, secVF.width, "top row width")
        assertEq(tl.height + bl.height, secVF.height, "left column height")
    },
] }

// MARK: - Entry point

func geometryTests() -> [Test] {
    axRectTests()
    + snapActionTests()
    + screenContainingTests()
    + pushThroughTests()
    + nonRegressionTests()
    + nonPrimaryScreenTests()
}
