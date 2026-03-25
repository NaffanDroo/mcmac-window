/// Bootstrap for McMac Window — a menu-bar-only (LSUIElement) agent.
/// The `.accessory` activation policy keeps the app out of the Dock
/// and the ⌘-Tab switcher; all interaction happens via the status item.
import AppKit
import McMacWindowCore

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
