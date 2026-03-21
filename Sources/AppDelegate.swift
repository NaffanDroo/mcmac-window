import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var accessibilityMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        HotkeyManager.shared.register()
        // Silently prompt the OS permission sheet (no custom alert).
        // kAXTrustedCheckOptionPrompt triggers the system sheet only when
        // permission has never been granted; it is a no-op once trusted.
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )
        updateAccessibilityMenuItem()
    }

    // MARK: - Menu bar icon

    /// Draws a 18×18 pt template image matching the app icon's split-panel motif.
    /// Rendered as a template so macOS applies correct tinting in light/dark mode.
    private func makeMenuBarImage() -> NSImage {
        let pt: CGFloat = 18
        let image = NSImage(size: NSSize(width: pt, height: pt), flipped: false) { _ in
            let pad: CGFloat = 1.0
            let gap: CGFloat = 1.5
            let cr:  CGFloat = 2.0
            let panelH = pt - pad * 2
            let panelW = (pt - pad * 2 - gap) / 2

            // Left panel — solid (active window)
            let leftRect = NSRect(x: pad, y: pad, width: panelW, height: panelH)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: leftRect, xRadius: cr, yRadius: cr).fill()

            // Right panel — ghost (inactive side), matches app icon's translucent panel
            let rightRect = NSRect(x: pad + panelW + gap, y: pad, width: panelW, height: panelH)
            NSColor.black.withAlphaComponent(0.28).setFill()
            NSBezierPath(roundedRect: rightRect, xRadius: cr, yRadius: cr).fill()

            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = makeMenuBarImage()
            button.toolTip = "mcmac-window"
        }

        let menu = NSMenu()
        menu.delegate = self

        let titleItem = NSMenuItem(title: "mcmac-window", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        // Accessibility status + request
        let axItem = NSMenuItem(title: "", action: #selector(requestAccessibility), keyEquivalent: "")
        axItem.target = self
        menu.addItem(axItem)
        accessibilityMenuItem = axItem

        // Reset permission
        let resetItem = NSMenuItem(title: "Reset Accessibility Permission…",
                                   action: #selector(resetAccessibility), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        menu.addItem(.separator())

        let shortcutsItem = NSMenuItem(title: "Shortcuts…",
                                       action: #selector(showShortcuts), keyEquivalent: "")
        shortcutsItem.target = self
        menu.addItem(shortcutsItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    // MARK: - Accessibility

    private func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    private func updateAccessibilityMenuItem() {
        if isAccessibilityTrusted() {
            accessibilityMenuItem?.title = "✓ Accessibility Enabled"
            accessibilityMenuItem?.action = nil          // not tappable when already granted
        } else {
            accessibilityMenuItem?.title = "⚠ Enable Accessibility…"
            accessibilityMenuItem?.action = #selector(requestAccessibility)
        }
    }

    @objc private func requestAccessibility() {
        // Trigger the system permission sheet.
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        )
        // Open System Settings in case the sheet doesn't appear (e.g. already denied).
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func resetAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Reset Accessibility Permission?"
        alert.informativeText = """
Removes the current Accessibility grant for mcmac-window so you can re-authorise it from scratch.

The app will relaunch automatically and prompt for permission again.
"""
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset & Relaunch")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let task = Process()
        task.launchPath = "/usr/bin/tccutil"
        task.arguments  = ["reset", "Accessibility", "com.example.mcmac-window"]
        try? task.run()
        task.waitUntilExit()

        // Relaunch via an independent shell process so the open(1) command
        // survives our own termination. NSWorkspace.openApplication is async
        // and gets cancelled when NSApp.terminate fires before it completes.
        let bundlePath = Bundle.main.bundleURL.path
        let relaunch = Process()
        relaunch.launchPath = "/bin/sh"
        relaunch.arguments  = ["-c", "sleep 1 && open '\(bundlePath)'"]
        try? relaunch.run()
        NSApp.terminate(nil)
    }

    // MARK: - Shortcuts panel

    @objc private func showShortcuts() {
        let alert = NSAlert()
        alert.messageText = "mcmac-window Shortcuts"
        alert.informativeText = HotkeyManager.shared.shortcutDescriptions().joined(separator: "\n")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    // Refresh the accessibility status label each time the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        updateAccessibilityMenuItem()
    }
}
