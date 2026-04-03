/// Centralised UserDefaults key constants shared across `McMacWindowCore`
/// and the `AppDelegate` layer.  All raw-value strings must remain stable —
/// changing them would silently lose persisted user preferences.
public enum UDKey: String {
    /// When `true`, all hotkey-triggered snaps are silently ignored.
    case snappingPaused = "snappingPaused"
    /// `[String]` of bundle identifiers whose windows should not be snapped.
    case ignoredBundleIDs = "ignoredBundleIDs"
    /// `[String]` of bundle identifiers for which the mouse gesture is disabled (opt-out denylist).
    case gestureDisabledBundleIDs = "gestureDisabledBundleIDs"
}
