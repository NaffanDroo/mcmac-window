import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        checkAccessibilityPermission()
        HotkeyManager.shared.register()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            if let img = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "mcmac-window") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "W"
            }
            button.toolTip = "mcmac-window"
        }

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "mcmac-window", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let shortcutsItem = NSMenuItem(title: "Shortcuts…", action: #selector(showShortcuts), keyEquivalent: "")
        shortcutsItem.target = self
        menu.addItem(shortcutsItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func showShortcuts() {
        let alert = NSAlert()
        alert.messageText = "mcmac-window Shortcuts"
        alert.informativeText = HotkeyManager.shared.shortcutDescriptions().joined(separator: "\n")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = """
mcmac-window needs Accessibility access to move and resize windows.

Please grant access in:
System Settings → Privacy & Security → Accessibility

Then relaunch mcmac-window.
"""
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
        }
    }
}
