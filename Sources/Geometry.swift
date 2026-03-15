import CoreGraphics

typealias ScreenInfo = (frame: CGRect, visibleFrame: CGRect)

// MARK: - Coordinate conversion

/// Converts a rect from NSScreen/AppKit coordinates (bottom-left origin, y-up)
/// into AX coordinates (top-left origin, y-down).
func axRect(from nsRect: CGRect, primaryScreenHeight ph: CGFloat) -> CGRect {
    let axY = ph - (nsRect.origin.y + nsRect.height)
    return CGRect(x: nsRect.origin.x, y: axY, width: nsRect.width, height: nsRect.height)
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
