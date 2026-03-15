import AppKit
import ApplicationServices

class WindowMover {

    static let shared = WindowMover()
    private init() {}

    // MARK: - Public API

    func move(action: WindowAction) {
        guard let window = focusedWindow() else { return }
        moveWindow(window, action: action)
    }

    /// Internal: lets integration tests pass a known AX element directly.
    func moveWindow(_ window: AXUIElement, action: WindowAction) {
        guard let axPos = windowPosition(window) else { return }

        let screens = NSScreen.screens.map { ScreenInfo(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        let ph      = NSScreen.screens.first?.frame.height ?? 0

        let vf     = screenContaining(axPoint: axPos, screens: screens, primaryScreenHeight: ph)
        let target = computeTargetRect(action: action, visibleFrame: vf,
                                       primaryScreenHeight: ph, currentAXOrigin: axPos)
        setFrame(target, on: window)
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
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let win = ref else { return nil }
        return (win as! AXUIElement)
    }

    // MARK: - AX read/write (internal for tests)

    func windowPosition(_ element: AXUIElement) -> CGPoint? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &ref) == .success,
              let axVal = ref else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axVal as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    func setFrame(_ rect: CGRect, on window: AXUIElement) {
        var origin = rect.origin
        if let posVal = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        }
        var size = rect.size
        if let sizeVal = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
        }
    }
}
