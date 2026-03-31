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
    var gestureButtonIndex: Int = 3
    var deltaThreshold: CGFloat = 60
    var cooldown: TimeInterval = 0.5

    // MARK: - State
    private(set) var gestureButtonHeld = false
    private(set) var accumulatedDelta: CGFloat = 0
    var lastSwitchTime: Date?

    // MARK: - Event tap
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {}

    // MARK: - Button state

    func handleMouseDown(button: Int) {
        guard button == gestureButtonIndex else { return }
        gestureButtonHeld = true
        logger.debug("gesture button down")
    }

    func handleMouseUp(button: Int) {
        guard button == gestureButtonIndex else { return }
        gestureButtonHeld = false
        accumulatedDelta = 0
        logger.debug("gesture button up, delta reset")
    }

    func handleMouseMoved(dx: CGFloat) {
        guard gestureButtonHeld else { return }
        guard let bundleID = frontmostBundleID(),
              gestureEnabledBundleIDs().contains(bundleID) else { return }
        guard !isSnappingPaused() else { return }

        accumulatedDelta += dx
        guard abs(accumulatedDelta) >= deltaThreshold else { return }
        if let last = lastSwitchTime, Date().timeIntervalSince(last) < cooldown { return }

        let direction: GestureDirection = accumulatedDelta > 0 ? .right : .left
        logger.debug("gesture threshold reached: \(direction == .right ? "right" : "left", privacy: .public)")
        switchAction(direction)
        accumulatedDelta = 0
        lastSwitchTime = Date()
    }

    private func gestureEnabledBundleIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: "gestureEnabledBundleIDs") ?? []
    }

    // MARK: - Space switching

    static func postSpaceSwitch(direction: GestureDirection) {
        let keyCode: CGKeyCode = direction == .right ? 124 : 123   // right / left arrow
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

    // MARK: - Event tap

    public func start() {
        if let stored = UserDefaults.standard.object(forKey: "gestureButtonIndex") as? Int {
            gestureButtonIndex = stored
        }

        let eventMask: CGEventMask =
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue)   |
            (1 << CGEventType.otherMouseDragged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let mgr = Unmanaged<MouseGestureManager>.fromOpaque(userInfo).takeUnretainedValue()
                mgr.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
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
        logger.info("MouseGestureManager started, monitoring button \(self.gestureButtonIndex)")
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

    private func handleEvent(type: CGEventType, event: CGEvent) {
        switch type {
        case .otherMouseDown:
            handleMouseDown(button: Int(event.getIntegerValueField(.mouseEventButtonNumber)))
        case .otherMouseUp:
            handleMouseUp(button: Int(event.getIntegerValueField(.mouseEventButtonNumber)))
        case .otherMouseDragged:
            handleMouseMoved(dx: CGFloat(event.getDoubleValueField(.mouseEventDeltaX)))
        default:
            break
        }
    }

    /// Exposed for testing only — returns whether the tap exists and is enabled.
    var eventTapIsEnabled: Bool? {
        guard let tap = eventTap else { return nil }
        return CGEvent.tapIsEnabled(tap: tap)
    }
}
