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

    Test("nextThirdRight: three cycles return window to starting x") {
        guard !NSScreen.screens.isEmpty, let vf = NSScreen.main?.visibleFrame else { try skip("no screen") }
        let window = makeTestWindow(); defer { window.close() }
        guard let ax = findAXWindow(titled: window.title) else { try skip("no AX element") }
        let ph = NSScreen.screens[0].frame.height
        let leftAXY = ph - (vf.origin.y + vf.height)
        WindowMover.shared.setFrame(CGRect(x: vf.origin.x, y: leftAXY, width: vf.width / 3, height: vf.height), on: ax)
        pump(0.08)
        let startX = window.frame.origin.x
        for _ in 0..<3 { WindowMover.shared.moveWindow(ax, action: .nextThirdRight); pump(0.08) }
        assertEq(window.frame.origin.x, startX, tol: 3, "after 3 right-cycles must return to start")
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
