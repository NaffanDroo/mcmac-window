import AppKit
import CoreGraphics
import OSLog

private let logger = Logger(subsystem: "org.nathandrew.mcmac-window", category: "MouseGestureManager")

// Time gap between flagsChanged (Command on) and keyDown(Tab) that distinguishes
// firmware button (<30ms) from a human keyboard press (>30ms).
private let cmdTabFirmwareThreshold: TimeInterval = 0.03

// How long to wait for mouse movement after suppressing a firmware Cmd+Tab.
private let gestureWindowDuration: TimeInterval = 0.4

public enum GestureDirection {
    case left, right
}

public class MouseGestureManager {

    // MARK: - Singleton
    public static let shared = MouseGestureManager()

    // MARK: - Injectable dependencies (overridden in tests)
    var switchAction: (GestureDirection) -> Void = { MouseGestureManager.postSpaceSwitch(direction: $0) }
    var frontmostBundleID: () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
    var isSnappingPaused: () -> Bool = { UserDefaults.standard.bool(forKey: "snappingPaused") }

    // MARK: - Configuration
    var deltaThreshold: CGFloat = 60
    var cooldown: TimeInterval = 0.5

    // MARK: - State
    // lastCmdDownTime: set by flagsChanged when Command goes on; cleared when it goes off.
    var lastCmdDownTime: Date?
    // gestureWindowOpen: true while waiting for directional mouse movement post-button-press.
    var gestureWindowOpen = false
    var gestureWindowOpened: Date?
    private(set) var accumulatedDelta: CGFloat = 0
    var lastSwitchTime: Date?

    // MARK: - Event tap
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {}

    deinit {
        stop()
    }

    // MARK: - Mouse moved

    func handleMouseMoved(dx: CGFloat) {
        guard gestureWindowOpen else { return }

        // Check expiry first — always close if window has lapsed.
        if let opened = gestureWindowOpened,
           Date().timeIntervalSince(opened) > gestureWindowDuration {
            gestureWindowOpen = false
            gestureWindowOpened = nil
            accumulatedDelta = 0
            logger.debug("gesture window expired without threshold")
            return
        }

        guard let bundleID = frontmostBundleID(),
              !gestureDisabledBundleIDs().contains(bundleID) else { return }
        guard !isSnappingPaused() else { return }

        accumulatedDelta += dx
        guard abs(accumulatedDelta) >= deltaThreshold else { return }

        if let last = lastSwitchTime, Date().timeIntervalSince(last) < cooldown {
            accumulatedDelta = 0
            return
        }

        let direction: GestureDirection = accumulatedDelta > 0 ? .right : .left
        logger.debug("gesture fired: \(direction == .right ? "right" : "left", privacy: .public)")
        switchAction(direction)
        accumulatedDelta = 0
        lastSwitchTime = Date()
        gestureWindowOpen = false
        gestureWindowOpened = nil
    }

    private func gestureDisabledBundleIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: "gestureDisabledBundleIDs") ?? []
    }

    // MARK: - Event handling (internal for tests)

    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .flagsChanged:
            if event.flags.contains(.maskCommand) {
                if lastCmdDownTime == nil {
                    lastCmdDownTime = Date()
                }
            } else {
                lastCmdDownTime = nil
            }

        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let hasCmd  = event.flags.contains(.maskCommand)
            guard keyCode == 48 && hasCmd else { break }
            guard let cmdDown = lastCmdDownTime else { break }
            let gap = Date().timeIntervalSince(cmdDown)
            guard gap < cmdTabFirmwareThreshold else { break }
            // Firmware button: suppress and open gesture window.
            if !gestureWindowOpen {
                gestureWindowOpen = true
                gestureWindowOpened = Date()
                accumulatedDelta = 0
                logger.debug("firmware Cmd+Tab suppressed, gesture window opened")
            }
            return nil

        case .mouseMoved:
            handleMouseMoved(dx: CGFloat(event.getDoubleValueField(.mouseEventDeltaX)))

        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Space switching

    static func postSpaceSwitch(direction: GestureDirection) {
        let keyCode: CGKeyCode = direction == .right ? 124 : 123
        let src = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = .maskControl
        up.flags   = .maskControl
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        logger.debug("posted space switch: \(direction == .right ? "right" : "left", privacy: .public)")
    }

    // MARK: - Lifecycle

    public func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)      |
            (1 << CGEventType.mouseMoved.rawValue)

        // passUnretained is safe because deinit calls stop(), closing the tap
        // before self is deallocated. Do not remove the deinit.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let mgr = Unmanaged<MouseGestureManager>.fromOpaque(userInfo).takeUnretainedValue()
                return mgr.handleEvent(type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            logger.error("CGEventTap creation failed — Accessibility permission likely not granted")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.info("MouseGestureManager started")
    }

    public func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        logger.info("MouseGestureManager stopped")
    }

    /// Exposed for testing only — returns whether the tap exists and is enabled.
    var eventTapIsEnabled: Bool? {
        guard let tap = eventTap else { return nil }
        return CGEvent.tapIsEnabled(tap: tap)
    }
}
