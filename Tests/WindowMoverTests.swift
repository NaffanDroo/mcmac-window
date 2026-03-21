import AppKit
import ApplicationServices

func windowMoverTests() -> [Test] { [

    Test("AX read/write round-trip: setFrame is reflected in NSWindow.frame") {
        guard let screen = NSScreen.main else { try skip("no screen") }
        let window = makeTestWindow()
        defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else {
            try skip("could not find AX element — Accessibility may be blocked")
        }
        let ph   = NSScreen.screens[0].frame.height
        let axVF = axRect(from: screen.visibleFrame, primaryScreenHeight: ph)
        let newOrigin = CGPoint(x: axVF.minX + 60, y: axVF.minY + 60)
        WindowMover.shared.setFrame(CGRect(origin: newOrigin, size: CGSize(width: 600, height: 450)), on: ax)
        pump()
        assertEq(window.frame.size.width,  600, tol: 3, "width")
        assertEq(window.frame.size.height, 450, tol: 3, "height")
        assertEq(window.frame.origin.x, newOrigin.x, tol: 3, "x")
    },

    Test("leftHalf: window fills left half of visibleFrame") {
        guard let vf = NSScreen.main?.visibleFrame else { try skip("no screen") }
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { try skip("no AX element") }
        WindowMover.shared.moveWindow(ax, action: .leftHalf); pump()
        assertEq(window.frame.origin.x,   vf.origin.x,  tol: 3, "x")
        assertEq(window.frame.size.width,  vf.width / 2, tol: 3, "w")
        assertEq(window.frame.size.height, vf.height,    tol: 3, "h")
    },

    Test("rightHalf: window fills right half of visibleFrame") {
        guard let vf = NSScreen.main?.visibleFrame else { try skip("no screen") }
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { try skip("no AX element") }
        WindowMover.shared.moveWindow(ax, action: .rightHalf); pump()
        assertEq(window.frame.origin.x,  vf.origin.x + vf.width / 2, tol: 3, "x")
        assertEq(window.frame.size.width, vf.width / 2,               tol: 3, "w")
    },

    Test("maximize: window fills entire visibleFrame") {
        guard let vf = NSScreen.main?.visibleFrame else { try skip("no screen") }
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { try skip("no AX element") }
        WindowMover.shared.moveWindow(ax, action: .maximize); pump()
        assertEq(window.frame.size.width,  vf.width,  tol: 3, "w")
        assertEq(window.frame.size.height, vf.height, tol: 3, "h")
    },

    Test("center: 65% of visibleFrame, horizontally centred") {
        guard let vf = NSScreen.main?.visibleFrame else { try skip("no screen") }
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { try skip("no AX element") }
        WindowMover.shared.moveWindow(ax, action: .center); pump()
        assertEq(window.frame.size.width,  vf.width  * 0.65, tol: 3, "w")
        assertEq(window.frame.size.height, vf.height * 0.65, tol: 3, "h")
        assertEq(window.frame.origin.x, vf.origin.x + (vf.width - vf.width * 0.65) / 2, tol: 3, "x")
    },

    Test("topLeft quarter: correct position and size") {
        guard let vf = NSScreen.main?.visibleFrame else { try skip("no screen") }
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { try skip("no AX element") }
        WindowMover.shared.moveWindow(ax, action: .topLeft); pump()
        assertEq(window.frame.size.width,  vf.width  / 2, tol: 3, "w")
        assertEq(window.frame.size.height, vf.height / 2, tol: 3, "h")
        assertEq(window.frame.origin.x,    vf.origin.x,   tol: 3, "x")
    },

    Test("push-through: pressing leftHalf twice on single screen stays at leftHalf") {
        // Verifies that push-through is a no-op when there is no adjacent screen.
        // On multi-screen machines this test exercises the same path but may succeed
        // with push-through; the invariant is that the window ends up snapped (not
        // in some undefined state).
        guard let vf = NSScreen.main?.visibleFrame else { try skip("no screen") }
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { try skip("no AX element") }
        WindowMover.shared.moveWindow(ax, action: .leftHalf); pump()
        WindowMover.shared.moveWindow(ax, action: .leftHalf); pump()
        if NSScreen.screens.count == 1 {
            // No adjacent screen — must stay at leftHalf of the only screen
            assertEq(window.frame.origin.x,    vf.origin.x,   tol: 3, "x")
            assertEq(window.frame.size.width,  vf.width / 2,  tol: 3, "w")
            assertEq(window.frame.size.height, vf.height,     tol: 3, "h")
        } else {
            // At least two screens — window must be snapped somewhere (not at arbitrary size)
            assertTrue(window.frame.size.width  > 0, "snapped width > 0")
            assertTrue(window.frame.size.height > 0, "snapped height > 0")
        }
    },

    Test("move: action is skipped when snapping is paused") {
        guard NSScreen.main != nil else { try skip("no screen") }
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { try skip("no AX element") }

        // Snap to a known position via the internal method (bypasses the pause guard).
        WindowMover.shared.moveWindow(ax, action: .leftHalf); pump()
        let savedX = window.frame.origin.x
        let savedW = window.frame.size.width

        // Pause snapping and call the public API — must be a no-op.
        UserDefaults.standard.set(true, forKey: "snappingPaused")
        defer { UserDefaults.standard.removeObject(forKey: "snappingPaused") }
        WindowMover.shared.move(action: .rightHalf); pump()

        assertEq(window.frame.origin.x,   savedX, tol: 3, "x unchanged while paused")
        assertEq(window.frame.size.width,  savedW, tol: 3, "w unchanged while paused")
    },

    Test("ignore list: entries persist in UserDefaults and can be removed") {
        // Tests the storage layer only; the move()-level skip requires a known
        // bundle ID from the frontmost app, which is unavailable in the headless
        // test runner (no Info.plist → nil bundleIdentifier).
        let key = "ignoredBundleIDs"
        let original = UserDefaults.standard.stringArray(forKey: key)
        defer { UserDefaults.standard.set(original, forKey: key) }

        UserDefaults.standard.set(["com.apple.finder", "com.google.Chrome"], forKey: key)
        let stored = UserDefaults.standard.stringArray(forKey: key) ?? []
        assertEq(stored.count, 2, "two entries stored")
        assertTrue(stored.contains("com.apple.finder"), "finder in list")
        assertTrue(stored.contains("com.google.Chrome"), "chrome in list")

        // Remove one entry.
        var updated = stored
        updated.removeAll { $0 == "com.apple.finder" }
        UserDefaults.standard.set(updated, forKey: key)
        let afterRemove = UserDefaults.standard.stringArray(forKey: key) ?? []
        assertEq(afterRemove.count, 1, "one entry after remove")
        assertTrue(!afterRemove.contains("com.apple.finder"), "finder removed")
        assertTrue(afterRemove.contains("com.google.Chrome"), "chrome still present")
    },

    Test("firstThird/centerThird/lastThird tile across full screen width") {
        guard !NSScreen.screens.isEmpty, let vf = NSScreen.main?.visibleFrame else { try skip("no screen") }
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { try skip("no AX element") }
        for action: WindowAction in [.firstThird, .centerThird, .lastThird] {
            WindowMover.shared.moveWindow(ax, action: action); pump(0.08)
            assertTrue(window.frame.size.width > 0, "\(action.rawValue) width > 0")
        }
        // All three widths should sum to the full visible width
        WindowMover.shared.moveWindow(ax, action: .firstThird); pump(0.08)
        let fw = window.frame.width
        WindowMover.shared.moveWindow(ax, action: .centerThird); pump(0.08)
        let cw = window.frame.width
        WindowMover.shared.moveWindow(ax, action: .lastThird); pump(0.08)
        let lw = window.frame.width
        assertEq(fw + cw + lw, vf.width, tol: 3, "thirds sum to full width")
    },

] }

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
