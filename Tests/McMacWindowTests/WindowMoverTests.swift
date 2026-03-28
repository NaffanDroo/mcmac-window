import XCTest
import AppKit
import ApplicationServices
@testable import McMacWindowCore

/// Tests that require creating NSWindows and manipulating them via AX.
/// When running under `swift test` (xctest CLI), the process may lack a
/// window-server connection, so we guard every window-creating test behind
/// `try requireAXAndScreen()` which skips early — before touching AppKit's
/// window machinery — if the environment can't support it.
class WindowMoverTests: XCTestCase {

    /// Returns the main screen's visibleFrame after verifying we have both
    /// a screen and AX trust. Throws `XCTSkip` if either is missing.
    private func requireAXAndScreen() throws -> NSRect {
        guard AXIsProcessTrusted() else {
            throw XCTSkip("Accessibility not trusted — skipping window test")
        }
        guard let vf = NSScreen.main?.visibleFrame else {
            throw XCTSkip("no screen")
        }
        return vf
    }

    func testAXReadWriteRoundTrip() throws {
        let visibleFrame = try requireAXAndScreen()
        let window = makeTestWindow()
        defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else {
            throw XCTSkip("could not find AX element")
        }
        let primaryHeight = NSScreen.screens[0].frame.height
        let axVF = axRect(from: visibleFrame, primaryScreenHeight: primaryHeight)
        let newOrigin = CGPoint(x: axVF.minX + 60, y: axVF.minY + 60)
        WindowMover.shared.setFrame(CGRect(origin: newOrigin, size: CGSize(width: 600, height: 450)), on: ax)
        pump()
        XCTAssertEqual(window.frame.size.width, 600, accuracy: 3, "width")
        XCTAssertEqual(window.frame.size.height, 450, accuracy: 3, "height")
        XCTAssertEqual(window.frame.origin.x, newOrigin.x, accuracy: 3, "x")
    }

    func testLeftHalf() throws {
        let visibleFrame = try requireAXAndScreen()
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { throw XCTSkip("no AX element") }
        WindowMover.shared.moveWindow(ax, action: .leftHalf); pump()
        XCTAssertEqual(window.frame.origin.x, visibleFrame.origin.x, accuracy: 3, "x")
        XCTAssertEqual(window.frame.size.width, visibleFrame.width / 2, accuracy: 3, "w")
        XCTAssertEqual(window.frame.size.height, visibleFrame.height, accuracy: 3, "h")
    }

    func testRightHalf() throws {
        let visibleFrame = try requireAXAndScreen()
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { throw XCTSkip("no AX element") }
        WindowMover.shared.moveWindow(ax, action: .rightHalf); pump()
        XCTAssertEqual(window.frame.origin.x, visibleFrame.origin.x + visibleFrame.width / 2, accuracy: 3, "x")
        XCTAssertEqual(window.frame.size.width, visibleFrame.width / 2, accuracy: 3, "w")
    }

    func testMaximize() throws {
        let visibleFrame = try requireAXAndScreen()
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { throw XCTSkip("no AX element") }
        WindowMover.shared.moveWindow(ax, action: .maximize); pump()
        XCTAssertEqual(window.frame.size.width, visibleFrame.width, accuracy: 3, "w")
        XCTAssertEqual(window.frame.size.height, visibleFrame.height, accuracy: 3, "h")
    }

    func testCenter() throws {
        let visibleFrame = try requireAXAndScreen()
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { throw XCTSkip("no AX element") }
        WindowMover.shared.moveWindow(ax, action: .center); pump()
        XCTAssertEqual(window.frame.size.width, visibleFrame.width * 0.65, accuracy: 3, "w")
        XCTAssertEqual(window.frame.size.height, visibleFrame.height * 0.65, accuracy: 3, "h")
        let expectedX = visibleFrame.origin.x + (visibleFrame.width - visibleFrame.width * 0.65) / 2
        XCTAssertEqual(window.frame.origin.x, expectedX, accuracy: 3, "x")
    }

    func testTopLeftQuarter() throws {
        let visibleFrame = try requireAXAndScreen()
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { throw XCTSkip("no AX element") }
        WindowMover.shared.moveWindow(ax, action: .topLeft); pump()
        XCTAssertEqual(window.frame.size.width, visibleFrame.width / 2, accuracy: 3, "w")
        XCTAssertEqual(window.frame.size.height, visibleFrame.height / 2, accuracy: 3, "h")
        XCTAssertEqual(window.frame.origin.x, visibleFrame.origin.x, accuracy: 3, "x")
    }

    func testPushThroughLeftHalfTwiceSingleScreen() throws {
        let visibleFrame = try requireAXAndScreen()
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { throw XCTSkip("no AX element") }
        WindowMover.shared.moveWindow(ax, action: .leftHalf); pump()
        WindowMover.shared.moveWindow(ax, action: .leftHalf); pump()
        if NSScreen.screens.count == 1 {
            XCTAssertEqual(window.frame.origin.x, visibleFrame.origin.x, accuracy: 3, "x")
            XCTAssertEqual(window.frame.size.width, visibleFrame.width / 2, accuracy: 3, "w")
            XCTAssertEqual(window.frame.size.height, visibleFrame.height, accuracy: 3, "h")
        } else {
            XCTAssertTrue(window.frame.size.width > 0, "snapped width > 0")
            XCTAssertTrue(window.frame.size.height > 0, "snapped height > 0")
        }
    }

    func testLoggingDoesNotWriteLegacyFile() throws {
        let logPath = "/tmp/mcmac-window.log"
        try? FileManager.default.removeItem(atPath: logPath)
        WindowMover.shared.move(action: .leftHalf)
        XCTAssertTrue(!FileManager.default.fileExists(atPath: logPath),
                      "legacy flat-file log must not exist after OSLog migration")
    }

    func testMoveSkippedWhenSnappingPaused() throws {
        _ = try requireAXAndScreen()
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { throw XCTSkip("no AX element") }

        WindowMover.shared.moveWindow(ax, action: .leftHalf); pump()
        let savedX = window.frame.origin.x
        let savedW = window.frame.size.width

        UserDefaults.standard.set(true, forKey: "snappingPaused")
        defer { UserDefaults.standard.removeObject(forKey: "snappingPaused") }
        WindowMover.shared.move(action: .rightHalf); pump()

        XCTAssertEqual(window.frame.origin.x, savedX, accuracy: 3, "x unchanged while paused")
        XCTAssertEqual(window.frame.size.width, savedW, accuracy: 3, "w unchanged while paused")
    }

    func testIgnoreListPersistence() throws {
        let key = "ignoredBundleIDs"
        let original = UserDefaults.standard.stringArray(forKey: key)
        defer { UserDefaults.standard.set(original, forKey: key) }

        UserDefaults.standard.set(["com.apple.finder", "com.google.Chrome"], forKey: key)
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        XCTAssertEqual(stored.count, 2, "two entries stored")
        XCTAssertTrue(stored.contains("com.apple.finder"), "finder in list")
        XCTAssertTrue(stored.contains("com.google.Chrome"), "chrome in list")

        var updated = stored
        updated.removeAll { $0 == "com.apple.finder" }
        UserDefaults.standard.set(updated, forKey: key)
        let afterRemove = UserDefaults.standard.stringArray(forKey: key) ?? []
        XCTAssertEqual(afterRemove.count, 1, "one entry after remove")
        XCTAssertTrue(!afterRemove.contains("com.apple.finder"), "finder removed")
        XCTAssertTrue(afterRemove.contains("com.google.Chrome"), "chrome still present")
    }

    func testThirdsTileAcrossFullWidth() throws {
        let visibleFrame = try requireAXAndScreen()
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { throw XCTSkip("no AX element") }
        for action: WindowAction in [.firstThird, .centerThird, .lastThird] {
            WindowMover.shared.moveWindow(ax, action: action); pump(0.08)
            XCTAssertTrue(window.frame.size.width > 0, "\(action.rawValue) width > 0")
        }
        WindowMover.shared.moveWindow(ax, action: .firstThird); pump(0.08)
        let fw = window.frame.width
        WindowMover.shared.moveWindow(ax, action: .centerThird); pump(0.08)
        let cw = window.frame.width
        WindowMover.shared.moveWindow(ax, action: .lastThird); pump(0.08)
        let lw = window.frame.width
        XCTAssertEqual(fw + cw + lw, visibleFrame.width, accuracy: 3, "thirds sum to full width")
    }

    // MARK: - Non-responsive window tests (issue #69)

    /// A normal resizable window should be reported as movable and resizable.
    func testIsMovableAndResizableForNormalWindow() throws {
        _ = try requireAXAndScreen()
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { throw XCTSkip("no AX element") }
        XCTAssertTrue(WindowMover.shared.isMovable(ax), "standard titled+resizable window should be movable")
        XCTAssertTrue(WindowMover.shared.isResizable(ax), "standard titled+resizable window should be resizable")
    }

    /// A window created without .resizable in its styleMask should report isResizable = false.
    func testIsResizableReturnsFalseForNonResizableWindow() throws {
        _ = try requireAXAndScreen()
        let window = makeNonResizableTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { throw XCTSkip("no AX element") }
        XCTAssertFalse(WindowMover.shared.isResizable(ax), "window without .resizable should report isResizable=false")
    }

    /// setFrame should return true when the AX writes succeed.
    func testSetFrameReturnsTrueForNormalWindow() throws {
        let visibleFrame = try requireAXAndScreen()
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { throw XCTSkip("no AX element") }
        let primaryHeight = NSScreen.screens[0].frame.height
        let axVF = axRect(from: visibleFrame, primaryScreenHeight: primaryHeight)
        let target = CGRect(origin: CGPoint(x: axVF.minX + 50, y: axVF.minY + 50),
                            size: CGSize(width: 600, height: 400))
        let result = WindowMover.shared.setFrame(target, on: ax)
        XCTAssertTrue(result, "setFrame should return true for a normal movable/resizable window")
    }

    /// For a non-resizable window, setFrame should still move the window (position write)
    /// but not attempt to resize it, and should return true (position succeeded).
    func testNonResizableWindowPositionIsStillUpdated() throws {
        let visibleFrame = try requireAXAndScreen()
        let window = makeNonResizableTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { throw XCTSkip("no AX element") }
        let originalSize = window.frame.size
        let primaryHeight = NSScreen.screens[0].frame.height
        let axVF = axRect(from: visibleFrame, primaryScreenHeight: primaryHeight)
        let newOrigin = CGPoint(x: axVF.minX + 80, y: axVF.minY + 80)
        let result = WindowMover.shared.setFrame(
            CGRect(origin: newOrigin, size: CGSize(width: 800, height: 600)), on: ax)
        pump()
        XCTAssertTrue(result, "setFrame should return true even for non-resizable window (position write can still succeed)")
        XCTAssertEqual(window.frame.origin.x, newOrigin.x, accuracy: 3, "x should be updated")
        // Size should remain at the original (non-resizable window ignores resize)
        XCTAssertEqual(window.frame.size.width, originalSize.width, accuracy: 3,
                       "width should be unchanged for non-resizable window")
    }
}

// MARK: - Helpers

private var _counter = 0

private func makeTestWindow() -> NSWindow {
    _counter += 1
    let w = NSWindow(
        contentRect: NSRect(x: 300, y: 300, width: 500, height: 400),
        styleMask: [.titled, .resizable, .closable],
        backing: .buffered, defer: false
    )
    w.title = "mcmac-test-\(_counter)-\(ProcessInfo.processInfo.processIdentifier)"
    w.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    pump(0.15)
    return w
}

/// Creates a window without .resizable in its styleMask, simulating apps like Notes
/// whose windows reject AX size writes (kAXResizableAttribute = false).
private func makeNonResizableTestWindow() -> NSWindow {
    _counter += 1
    let w = NSWindow(
        contentRect: NSRect(x: 300, y: 300, width: 500, height: 400),
        styleMask: [.titled, .closable],
        backing: .buffered, defer: false
    )
    w.title = "mcmac-test-noresize-\(_counter)-\(ProcessInfo.processInfo.processIdentifier)"
    w.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    pump(0.15)
    return w
}

private func findAXWindow(titled title: String) -> AXUIElement? {
    let axApp = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
    var ref: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref) == .success,
          let wins = ref as? [AXUIElement] else { return nil }
    for win in wins {
        var t: CFTypeRef?
        AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &t)
        if (t as? String) == title { return win }
    }
    return nil
}

private func pump(_ seconds: Double = 0.12) {
    RunLoop.current.run(until: Date(timeIntervalSinceNow: seconds))
}
