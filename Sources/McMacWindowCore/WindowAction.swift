/// A snap action that positions a window within the current screen's visible frame.
/// Raw values are human-readable names used in logs and the shortcuts panel.
public enum WindowAction: String {
    // Halves — split the screen along one axis
    case leftHalf       = "Left Half"
    case rightHalf      = "Right Half"
    case topHalf        = "Top Half"
    case bottomHalf     = "Bottom Half"
    // Quarters — each corner of the screen
    case topLeft        = "Top Left"
    case topRight       = "Top Right"
    case bottomLeft     = "Bottom Left"
    case bottomRight    = "Bottom Right"
    // Full / centred
    case maximize       = "Maximize"
    case center         = "Center"
    // Thirds — vertical columns
    case firstThird      = "First Third"
    case centerThird     = "Center Third"
    case lastThird       = "Last Third"
    case leftTwoThirds   = "Left Two Thirds"
    case rightTwoThirds  = "Right Two Thirds"
}
