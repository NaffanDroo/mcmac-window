import AppKit
import CoreGraphics
import OSLog

private let logger = Logger(subsystem: "org.nathandrew.mcmac-window", category: "MouseGestureManager")

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
    // var (not private(set)) so tests can inject button-held state directly.
    var gestureButtonHeld = false
    private(set) var accumulatedDelta: CGFloat = 0
    var lastSwitchTime: Date?
    var lastButtonDownTime: Date?

    // MARK: - IOHIDButtonTracker
    private(set) var tracker = IOHIDButtonTracker()

    // MARK: - Event tap
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {
        tracker.onButtonDown = { [weak self] in
            self?.gestureButtonHeld = true
            self?.lastButtonDownTime = Date()
        }
        tracker.onButtonUp = { [weak self] in
            self?.gestureButtonHeld = false
            self?.accumulatedDelta = 0
        }
    }

    deinit {
        stop()
    }

    // MARK: - Mouse moved

    func handleMouseMoved(dx: CGFloat) {
        guard gestureButtonHeld else { return }
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
        logger.debug("gesture threshold reached: \(direction == .right ? "right" : "left", privacy: .public)")
        switchAction(direction)
        accumulatedDelta = 0
        lastSwitchTime = Date()
    }

    private func gestureDisabledBundleIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: "gestureDisabledBundleIDs") ?? []
    }

    // MARK: - Event handling (internal for tests)

    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .mouseMoved:
            handleMouseMoved(dx: CGFloat(event.getDoubleValueField(.mouseEventDeltaX)))
        case .keyDown:
            let keyCode  = event.getIntegerValueField(.keyboardEventKeycode)
            let hasCmd   = event.flags.contains(.maskCommand)
            // 50ms window: firmware Cmd+Tab can arrive slightly after the HID button-down callback.
            let inWindow = lastButtonDownTime.map { Date().timeIntervalSince($0) < 0.05 } ?? false
            if keyCode == 48 && hasCmd && (gestureButtonHeld || inWindow) {
                logger.debug("suppressing firmware Cmd+Tab")
                return nil
            }
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
        tracker.start()

        let eventMask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

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
        tracker.stop()
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
