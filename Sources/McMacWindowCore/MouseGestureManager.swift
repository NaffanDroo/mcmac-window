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

        accumulatedDelta += dx
        guard abs(accumulatedDelta) >= deltaThreshold else { return }

        let direction: GestureDirection = accumulatedDelta > 0 ? .right : .left
        logger.debug("gesture threshold reached: \(direction == .right ? "right" : "left", privacy: .public)")
        switchAction(direction)
        accumulatedDelta = 0
        lastSwitchTime = Date()
    }

    // MARK: - Space switching (implemented in Task 5)

    static func postSpaceSwitch(direction: GestureDirection) {}

    // MARK: - Event tap (implemented in Task 5)

    public func start() {}
    public func stop() {}
}
