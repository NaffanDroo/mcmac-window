import AppKit
import ApplicationServices

private let logPath = "/tmp/mcmac-window.log"
private func mlog(_ msg: String) {
    let line = "\(Date()) \(msg)\n"
    if let data = line.data(using: .utf8) {
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile(); handle.write(data); handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: data)
        }
    }
}

class WindowMover {

    static let shared = WindowMover()
    private init() {}

    // MARK: - Public API

    func move(action: WindowAction) {
        mlog("move(\(action.rawValue)) triggered")
        guard let window = focusedWindow() else {
            mlog("focusedWindow() returned nil — AX permission likely missing or revoked")
            return
        }
        mlog("got focused window, calling moveWindow")
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
        mlog("setFrame \(target) on window")
        setFrame(target, on: window)
        mlog("setFrame complete")
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
            mlog("frontmostApplication is nil")
            return nil
        }
        mlog("frontmostApplication = \(app.bundleIdentifier ?? app.localizedName ?? "?") pid=\(app.processIdentifier)")
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &ref)
        if result != .success {
            mlog("AXUIElementCopyAttributeValue(kAXFocusedWindowAttribute) failed — AXError \(result.rawValue) (likely no Accessibility permission)")
            return nil
        }
        guard let win = ref else { return nil }
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
