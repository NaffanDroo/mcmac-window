import AppKit
import CoreGraphics
import OSLog

private let logger = Logger(
    subsystem: "org.nathandrew.mcmac-window", category: "MouseGestureManager")

// Fallback detector for devices that do not expose gesture thumb button via IOHID button usages.
private let cmdTabFirmwareThreshold: TimeInterval = 0.03

public enum GestureDirection {
    case left, right
}

public class MouseGestureManager {

    // MARK: - Singleton
    public static let shared = MouseGestureManager()

    // MARK: - Injectable dependencies (overridden in tests)
    var switchAction: (GestureDirection) -> Void = {
        MouseGestureManager.postSpaceSwitch(direction: $0)
    }
    var frontmostBundleID: () -> String? = {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    var isSnappingPaused: () -> Bool = {
        UserDefaults.standard.bool(forKey: UDKey.snappingPaused.rawValue)
    }
    var buttonTracker: IOHIDButtonTracker = IOHIDButtonTracker()

    // MARK: - Configuration
    var deltaThreshold: CGFloat = 60
    var cooldown: TimeInterval = 0.5

    // MARK: - State
    // gestureWindowOpen: true when the physical button is held down
    var gestureWindowOpen = false
    var accumulatedDelta: CGFloat = 0
    var lastSwitchTime: Date?
    var lastCmdDownTime: Date?

    // MARK: - Event tap (mouse movement only)
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {}

    deinit {
        stop()
    }

    // MARK: - Mouse moved

    func handleMouseMoved(dx: CGFloat) {
        guard gestureWindowOpen else { return }

        guard let bundleID = frontmostBundleID(),
            !gestureDisabledBundleIDs().contains(bundleID)
        else {
            accumulatedDelta = 0
            return
        }
        guard !isSnappingPaused() else {
            accumulatedDelta = 0
            return
        }

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
    }

    private func gestureDisabledBundleIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: UDKey.gestureDisabledBundleIDs.rawValue) ?? []
    }

    // MARK: - Button state (called by IOHIDButtonTracker)

    func handleButtonDown() {
        gestureWindowOpen = true
        accumulatedDelta = 0
        logger.debug("gesture window opened (button down)")
    }

    func handleButtonUp() {
        gestureWindowOpen = false
        accumulatedDelta = 0
        logger.debug("gesture window closed (button up)")
    }

    // MARK: - Event handling (internal for tests, mouse movement only)

    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // Re-enable the tap so gestures don't silently stop working.
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                let reason = type == .tapDisabledByTimeout ? "timeout" : "userInput"
                logger.warning("CGEventTap disabled (\(reason, privacy: .public)); re-enabled")
            }
            return Unmanaged.passUnretained(event)

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
            let hasCmd = event.flags.contains(.maskCommand)
            guard keyCode == 48 && hasCmd else { break }
            guard let cmdDown = lastCmdDownTime else { break }
            let gap = Date().timeIntervalSince(cmdDown)
            guard gap < cmdTabFirmwareThreshold else { break }
            if !gestureWindowOpen {
                gestureWindowOpen = true
                accumulatedDelta = 0
                logger.debug("gesture window opened (Cmd+Tab fallback)")
            }

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
            let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = .maskControl
        up.flags = .maskControl
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        logger.debug(
            "posted space switch: \(direction == .right ? "right" : "left", privacy: .public)")
    }

    // MARK: - Lifecycle

    public func start() {
        guard eventTap == nil else { return }

        // Start button tracker (detects physical button presses)
        buttonTracker.onButtonDown = { [weak self] in self?.handleButtonDown() }
        buttonTracker.onButtonUp = { [weak self] in self?.handleButtonUp() }
        buttonTracker.start()

        // Create event tap for mouse movement tracking + Cmd+Tab fallback detection
        let eventMask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.mouseMoved.rawValue)

        // passUnretained is safe because deinit calls stop(), closing the tap
        // before self is deallocated. Do not remove the deinit.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard
            let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                // Listen-only tap cannot suppress or mutate global input,
                // preventing accidental keyboard lockups if callback logic misbehaves.
                options: .listenOnly,
                eventsOfInterest: eventMask,
                callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                    guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                    let mgr = Unmanaged<MouseGestureManager>.fromOpaque(userInfo)
                        .takeUnretainedValue()
                    return mgr.handleEvent(type: type, event: event)
                },
                userInfo: selfPtr
            )
        else {
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
        buttonTracker.stop()
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
