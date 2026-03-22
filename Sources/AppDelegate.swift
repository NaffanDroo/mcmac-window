import AppKit
import ApplicationServices

private enum UDKey {
    static let snappingPaused   = "snappingPaused"
    static let ignoredBundleIDs = "ignoredBundleIDs"
}

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var accessibilityMenuItem: NSMenuItem?
    private var pauseMenuItem: NSMenuItem?
    private var ignoreMenuItem: NSMenuItem?
    private var manageIgnoredMenuItem: NSMenuItem?

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
        // Restore paused-state icon on relaunch.
        statusItem?.button?.appearsDisabled = isSnappingPaused()
        // One-time migration: remove the stale TCC entry from the old bundle ID
        // (com.example.mcmac-window) so it no longer appears in System Settings.
        if !UserDefaults.standard.bool(forKey: "legacyBundleIDCleaned") {
            let cleanup = Process()
            cleanup.launchPath = "/usr/bin/tccutil"
            cleanup.arguments  = ["reset", "Accessibility", "com.example.mcmac-window"]
            try? cleanup.run()
            cleanup.waitUntilExit()
            if cleanup.terminationStatus == 0 {
                UserDefaults.standard.set(true, forKey: "legacyBundleIDCleaned")
            }
        }
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
            button.toolTip = "McMac Window"
        }

        let menu = NSMenu()
        menu.delegate = self

        let titleItem = NSMenuItem(title: "McMac Window", action: nil, keyEquivalent: "")
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

        // Pause snapping
        let pauseItem = NSMenuItem(title: "Pause Snapping",
                                   action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        pauseMenuItem = pauseItem
        menu.addItem(.separator())

        // Per-app ignore
        let ignoreItem = NSMenuItem(title: "Ignore This App",
                                    action: #selector(toggleIgnoreCurrentApp), keyEquivalent: "")
        ignoreItem.target = self
        menu.addItem(ignoreItem)
        ignoreMenuItem = ignoreItem

        let manageItem = NSMenuItem(title: "Manage Ignored Apps…",
                                    action: #selector(showManageIgnored), keyEquivalent: "")
        manageItem.target = self
        menu.addItem(manageItem)
        manageIgnoredMenuItem = manageItem
        menu.addItem(.separator())

        let shortcutsItem = NSMenuItem(title: "Shortcuts…",
                                       action: #selector(showShortcuts), keyEquivalent: "")
        shortcutsItem.target = self
        menu.addItem(shortcutsItem)
        menu.addItem(.separator())

        let openLogsItem = NSMenuItem(title: "Open Logs in Console…",
                                      action: #selector(openLogsInConsole), keyEquivalent: "")
        openLogsItem.target = self
        menu.addItem(openLogsItem)

        let exportLogsItem = NSMenuItem(title: "Export Logs…",
                                        action: #selector(exportLogs), keyEquivalent: "")
        exportLogsItem.target = self
        menu.addItem(exportLogsItem)
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
Removes the current Accessibility grant for McMac Window so you can re-authorise it from scratch.

The app will relaunch automatically and prompt for permission again.
"""
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset & Relaunch")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let task = Process()
        task.launchPath = "/usr/bin/tccutil"
        task.arguments  = ["reset", "Accessibility", "org.nathandrew.mcmac-window"]
        try? task.run()
        task.waitUntilExit()

        // Relaunch via an independent shell process so the open(1) command
        // survives our own termination. NSWorkspace.openApplication is async
        // and gets cancelled when NSApp.terminate fires before it completes.
        let bundlePath = Bundle.main.bundleURL.path
        let relaunch = Process()
        relaunch.launchPath = "/bin/sh"
        relaunch.arguments  = ["-c", "sleep 1 && open \"$MCMAC_RELAUNCH_PATH\""]
        relaunch.environment = ProcessInfo.processInfo.environment.merging(
            ["MCMAC_RELAUNCH_PATH": bundlePath]) { _, new in new }
        try? relaunch.run()
        NSApp.terminate(nil)
    }

    // MARK: - Pause snapping

    private func isSnappingPaused() -> Bool {
        UserDefaults.standard.bool(forKey: UDKey.snappingPaused)
    }

    @objc private func togglePause() {
        let nowPaused = !isSnappingPaused()
        UserDefaults.standard.set(nowPaused, forKey: UDKey.snappingPaused)
        statusItem?.button?.appearsDisabled = nowPaused
    }

    private func updatePauseMenuItem() {
        pauseMenuItem?.title = isSnappingPaused() ? "Resume Snapping" : "Pause Snapping"
    }

    // MARK: - Per-app ignore list

    private func ignoredBundleIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: UDKey.ignoredBundleIDs) ?? []
    }

    private func setIgnoredBundleIDs(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: UDKey.ignoredBundleIDs)
    }

    private func displayName(for bundleID: String) -> String {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first?.localizedName ?? bundleID
    }

    @objc private func toggleIgnoreCurrentApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else { return }
        var ids = ignoredBundleIDs()
        if let idx = ids.firstIndex(of: bundleID) {
            ids.remove(at: idx)
        } else {
            ids.append(bundleID)
        }
        setIgnoredBundleIDs(ids)
    }

    private func updateIgnoreMenuItem() {
        let paused = isSnappingPaused()
        ignoreMenuItem?.isHidden = paused
        manageIgnoredMenuItem?.isHidden = paused
        guard !paused,
              let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier else {
            ignoreMenuItem?.title = "Ignore This App"
            ignoreMenuItem?.isEnabled = false
            return
        }
        let name = app.localizedName ?? bundleID
        let isIgnored = ignoredBundleIDs().contains(bundleID)
        ignoreMenuItem?.title = isIgnored ? "✓ Ignoring \(name)" : "Ignore \(name)"
        ignoreMenuItem?.isEnabled = true
    }

    @objc private func showManageIgnored() {
        let ids = ignoredBundleIDs()
        guard !ids.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No Ignored Apps"
            alert.informativeText = "Use \u{201C}Ignore [App]\u{201D} from the menu to add apps to the ignore list."
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }

        let names = ids.map { displayName(for: $0) }
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 260, height: 26))
        for name in names { popup.addItem(withTitle: name) }

        let alert = NSAlert()
        alert.messageText = "Ignored Apps"
        alert.informativeText = "Select an app to stop ignoring:"
        alert.accessoryView = popup
        alert.addButton(withTitle: "Stop Ignoring")
        alert.addButton(withTitle: "Done")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            var updated = ids
            updated.remove(at: popup.indexOfSelectedItem)
            setIgnoredBundleIDs(updated)
        }
    }

}

// MARK: - Logs

extension AppDelegate {
    @objc func openLogsInConsole() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
        let alert = NSAlert()
        alert.messageText = "Filter by Subsystem"
        alert.informativeText = "In Console, set the search filter to:\n\norg.nathandrew.mcmac-window"
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc func exportLogs() {
        let panel = NSSavePanel()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "mcmac-window-\(formatter.string(from: Date())).log"
        panel.title = "Export Logs"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let task = Process()
        task.launchPath = "/usr/bin/log"
        task.arguments = [
            "show",
            "--predicate", "subsystem == \"org.nathandrew.mcmac-window\"",
            "--last", "1d",
            "--info",
            "--debug"
        ]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
        } catch {
            let errAlert = NSAlert()
            errAlert.messageText = "Export Failed"
            errAlert.informativeText = "Could not run the log command: \(error.localizedDescription)"
            errAlert.addButton(withTitle: "OK")
            errAlert.runModal()
            return
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        do {
            try data.write(to: url)
        } catch {
            let errAlert = NSAlert()
            errAlert.messageText = "Export Failed"
            errAlert.informativeText = "Could not write log file: \(error.localizedDescription)"
            errAlert.addButton(withTitle: "OK")
            errAlert.runModal()
            return
        }
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}

// MARK: - Shortcuts panel

extension AppDelegate {
    @objc func showShortcuts() {
        let alert = NSAlert()
        alert.messageText = "McMac Window Shortcuts"
        alert.informativeText = HotkeyManager.shared.shortcutDescriptions().joined(separator: "\n")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    // Refresh dynamic menu items each time the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        updateAccessibilityMenuItem()
        updatePauseMenuItem()
        updateIgnoreMenuItem()
    }
}
