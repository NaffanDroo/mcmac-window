import CoreGraphics

typealias ScreenInfo = (frame: CGRect, visibleFrame: CGRect)

// MARK: - Coordinate conversion

/// Converts a rect from NSScreen/AppKit coordinates (bottom-left origin, y-up)
/// into AX coordinates (top-left origin, y-down).
func axRect(from nsRect: CGRect, primaryScreenHeight ph: CGFloat) -> CGRect {
    let axY = ph - (nsRect.origin.y + nsRect.height)
    return CGRect(x: nsRect.origin.x, y: axY, width: nsRect.width, height: nsRect.height)
}

// MARK: - Push-through support

/// Direction used for cross-screen push-through.
enum SnapDirection: Equatable {
    case left, right, up, down
}

/// Maps a snap action to the mirror action and direction used when the window
/// is already at the target position and the user presses the hotkey again.
/// Returns nil for actions that have no meaningful push-through (maximize, center,
/// cycling thirds — these either fill the screen or already cycle internally).
func pushThrough(for action: WindowAction) -> (action: WindowAction, direction: SnapDirection)? {
    switch action {
    case .leftHalf:      return (.rightHalf,     .left)
    case .rightHalf:     return (.leftHalf,      .right)
    case .topHalf:       return (.bottomHalf,    .up)
    case .bottomHalf:    return (.topHalf,       .down)
    case .topLeft:       return (.topRight,      .left)
    case .topRight:      return (.topLeft,       .right)
    case .bottomLeft:    return (.bottomRight,   .left)
    case .bottomRight:   return (.bottomLeft,    .right)
    case .leftTwoThirds: return (.rightTwoThirds, .left)
    case .rightTwoThirds:return (.leftTwoThirds,  .right)
    case .maximize, .center, .nextThirdLeft, .nextThirdRight: return nil
    }
}

/// Finds the screen immediately adjacent in the given direction.
/// Uses AppKit visibleFrame midpoints for direction detection so the result
/// is robust to irregular dock/menubar insets that prevent frames from touching.
func adjacentScreen(to currentVF: CGRect, direction: SnapDirection, among screens: [ScreenInfo]) -> ScreenInfo? {
    switch direction {
    case .left:
        return screens
            .filter { $0.visibleFrame.midX < currentVF.midX }
            .max(by: { $0.visibleFrame.midX < $1.visibleFrame.midX })
    case .right:
        return screens
            .filter { $0.visibleFrame.midX > currentVF.midX }
            .min(by: { $0.visibleFrame.midX < $1.visibleFrame.midX })
    case .up:
        // AppKit y increases upward, so "above" = larger midY
        return screens
            .filter { $0.visibleFrame.midY > currentVF.midY }
            .min(by: { $0.visibleFrame.midY < $1.visibleFrame.midY })
    case .down:
        return screens
            .filter { $0.visibleFrame.midY < currentVF.midY }
            .max(by: { $0.visibleFrame.midY < $1.visibleFrame.midY })
    }
}

/// Returns true when two AX-coordinate rects are within `tolerance` pixels on
/// every dimension. Used to detect when a window is already at its snap target.
func rectsMatch(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 2) -> Bool {
    abs(a.origin.x    - b.origin.x)    <= tolerance &&
    abs(a.origin.y    - b.origin.y)    <= tolerance &&
    abs(a.size.width  - b.size.width)  <= tolerance &&
    abs(a.size.height - b.size.height) <= tolerance
}

// MARK: - Screen detection

/// Returns the visibleFrame of the screen that contains `axPoint`.
/// Falls back to the first screen's visibleFrame when no screen matches.
func screenContaining(axPoint: CGPoint, screens: [ScreenInfo], primaryScreenHeight ph: CGFloat) -> CGRect {
    let appKitPoint = CGPoint(x: axPoint.x, y: ph - axPoint.y)
    let match = screens.first { $0.frame.contains(appKitPoint) }
    return match?.visibleFrame ?? screens.first?.visibleFrame ?? .zero
}

// MARK: - Target rect

/// Computes the destination frame (in AX coordinates) for a snap action.
func computeTargetRect(
    action: WindowAction,
    visibleFrame vf: CGRect,
    primaryScreenHeight ph: CGFloat,
    currentAXOrigin: CGPoint
) -> CGRect {
    let ax = axRect(from: vf, primaryScreenHeight: ph)
    let w  = vf.width
    let h  = vf.height

    switch action {
    case .leftHalf:    return CGRect(x: ax.minX,       y: ax.minY,       width: w / 2, height: h)
    case .rightHalf:   return CGRect(x: ax.minX + w/2, y: ax.minY,       width: w / 2, height: h)
    case .topHalf:     return CGRect(x: ax.minX,       y: ax.minY,       width: w,     height: h / 2)
    case .bottomHalf:  return CGRect(x: ax.minX,       y: ax.minY + h/2, width: w,     height: h / 2)
    case .topLeft:     return CGRect(x: ax.minX,       y: ax.minY,       width: w / 2, height: h / 2)
    case .topRight:    return CGRect(x: ax.minX + w/2, y: ax.minY,       width: w / 2, height: h / 2)
    case .bottomLeft:  return CGRect(x: ax.minX,       y: ax.minY + h/2, width: w / 2, height: h / 2)
    case .bottomRight: return CGRect(x: ax.minX + w/2, y: ax.minY + h/2, width: w / 2, height: h / 2)
    case .maximize:    return CGRect(x: ax.minX,       y: ax.minY,       width: w,     height: h)

    case .center:
        let tw = w * 0.65
        let th = h * 0.65
        return CGRect(x: ax.minX + (w - tw) / 2, y: ax.minY + (h - th) / 2, width: tw, height: th)

    case .nextThirdLeft:
        return nextThirdRect(direction: -1, ax: ax, w: w, h: h, currentX: currentAXOrigin.x)
    case .nextThirdRight:
        return nextThirdRect(direction: +1, ax: ax, w: w, h: h, currentX: currentAXOrigin.x)

    case .leftTwoThirds:  return CGRect(x: ax.minX,           y: ax.minY, width: w * 2 / 3, height: h)
    case .rightTwoThirds: return CGRect(x: ax.minX + w / 3,   y: ax.minY, width: w * 2 / 3, height: h)
    }
}

private func nextThirdRect(direction: Int, ax: CGRect, w: CGFloat, h: CGFloat, currentX: CGFloat) -> CGRect {
    let third = w / 3
    let slots: [CGFloat] = [ax.minX, ax.minX + third, ax.minX + third * 2]

    var currentSlot = 0
    var minDist = abs(currentX - slots[0])
    for (i, sx) in slots.enumerated() {
        let d = abs(currentX - sx)
        if d < minDist { minDist = d; currentSlot = i }
    }

    let nextSlot = (currentSlot + direction + 3) % 3
    return CGRect(x: slots[nextSlot], y: ax.minY, width: third, height: h)
}
