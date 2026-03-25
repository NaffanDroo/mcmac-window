/// Modal panels triggered from the status-bar menu: About, Shortcuts, and Logs.
import AppKit

// MARK: - About panel

extension AppDelegate {
    @objc func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let alert = NSAlert()
        alert.messageText = "McMac Window"
        alert.informativeText = """
        Version \(version)

        A lightweight macOS window manager — snap any window \
        into place with a hotkey.

        Author: Nathan Drew
        MIT License
        https://github.com/NaffanDroo/mcmac-window
        """
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open GitHub")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertSecondButtonReturn,
           let url = URL(string: "https://github.com/NaffanDroo/mcmac-window") {
            NSWorkspace.shared.open(url)
        }
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
