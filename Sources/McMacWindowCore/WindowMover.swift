import AppKit
import ApplicationServices
import OSLog

private let logger = Logger(subsystem: "org.nathandrew.mcmac-window", category: "WindowMover")

public class WindowMover {

    public static let shared = WindowMover()
    private init() {}

    // MARK: - Public API

    public func move(action: WindowAction) {
        logger.debug("move triggered: \(action.rawValue, privacy: .public)")

        guard !UserDefaults.standard.bool(forKey: "snappingPaused") else {
            logger.info("snapping paused — action skipped")
            return
        }

        let ignoredIDs = UserDefaults.standard.stringArray(forKey: "ignoredBundleIDs") ?? []
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           ignoredIDs.contains(bundleID) {
            logger.info("app \(bundleID, privacy: .public) is on ignore list — action skipped")
            return
        }

        guard let window = focusedWindow() else {
            logger.error("focusedWindow() returned nil — AX permission likely missing or revoked")
            return
        }
        logger.debug("got focused window, calling moveWindow")
        moveWindow(window, action: action)
    }

    /// Internal: lets integration tests pass a known AX element directly.
    public func moveWindow(_ window: AXUIElement, action: WindowAction) {
        guard let axPos  = windowPosition(window),
              let axSize = windowSize(window) else { return }

        let screens = NSScreen.screens.map { ScreenInfo(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        let ph      = NSScreen.screens.first?.frame.height ?? 0

        let vf     = screenContaining(axPoint: axPos, screens: screens, primaryScreenHeight: ph)
        let target = computeTargetRect(action: action, visibleFrame: vf,
                                       primaryScreenHeight: ph, currentAXOrigin: axPos)

        // Push-through: if the window is already at the snap target and the action
        // has a directional mirror (e.g. leftHalf → rightHalf on the left screen),
        // move to the mirror position on the adjacent screen instead.
        let currentRect = CGRect(origin: axPos, size: axSize)
        if rectsMatch(currentRect, target),
           let pt       = pushThrough(for: action),
           let neighbor = adjacentScreen(to: vf, direction: pt.direction, among: screens) {
            let pushTarget = computeTargetRect(action: pt.action, visibleFrame: neighbor.visibleFrame,
                                               primaryScreenHeight: ph, currentAXOrigin: axPos)
            logger.debug("push-through: \(action.rawValue, privacy: .public) → \(pt.action.rawValue, privacy: .public) on adjacent screen")
            setFrame(pushTarget, on: window)
            return
        }

        logger.debug("setFrame \(target.debugDescription, privacy: .public)")
        setFrame(target, on: window)
        logger.debug("setFrame complete")
    }

    // MARK: - Focused window

    /// Uses NSWorkspace.frontmostApplication — NOT kAXFocusedApplicationAttribute.
    ///
    /// Root cause of the original bug: Carbon's RegisterEventHotKey delivers the
    /// hotkey event to *our* app's event queue. At that moment, the system-wide AX
    /// "focused application" attribute can transiently point at our own process
    /// (an LSUIElement agent), returning nil or our own windows instead of the target.
    ///
    /// NSWorkspace.frontmostApplication tracks the last non-background app to have
    /// user focus. Because our app is LSUIElement=true, we never appear here, so
    /// this always returns the correct target app.
    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            logger.info("frontmostApplication is nil")
            return nil
        }
        let appID = app.bundleIdentifier ?? app.localizedName ?? "?"
        logger.debug("frontmostApplication = \(appID, privacy: .public) pid=\(app.processIdentifier)")
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref)
        if result != .success {
            logger.error("kAXFocusedWindowAttribute failed — AXError \(result.rawValue) (likely no AX permission)")
            return nil
        }
        guard let win = ref else { return nil }
        // AXUIElementCopyAttributeValue always returns an AXUIElement for kAXFocusedWindowAttribute.
        // Parentheses silence the "forced downcast will never produce nil" compiler warning;
        // as? is rejected here because AXUIElement is a CF type (the conditional cast always succeeds).
        return (win as! AXUIElement) // swiftlint:disable:this force_cast
    }

    // MARK: - AX read/write (internal for tests)

    public func windowPosition(_ element: AXUIElement) -> CGPoint? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &ref) == .success,
              let axVal = ref else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axVal as! AXValue, .cgPoint, &point) else { return nil } // swiftlint:disable:this force_cast
        return point
    }

    public func windowSize(_ element: AXUIElement) -> CGSize? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &ref) == .success,
              let axVal = ref else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axVal as! AXValue, .cgSize, &size) else { return nil } // swiftlint:disable:this force_cast
        return size
    }

    public func setFrame(_ rect: CGRect, on window: AXUIElement) {
        // Set size first, then position, then size again. This order handles
        // cross-screen moves in both directions: when moving to a smaller screen
        // the first resize prevents the window server from clamping the position;
        // the second resize corrects any clamping that happened during the move
        // to a larger screen. This is the same strategy used by Rectangle.
        var size = rect.size
        if let sizeVal = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
        }
        var origin = rect.origin
        if let posVal = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        }
        if let sizeVal = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
        }
    }
}
