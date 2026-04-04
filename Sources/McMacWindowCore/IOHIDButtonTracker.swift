import Foundation
import IOKit
import IOKit.hid
import OSLog

private let logger = Logger(
    subsystem: "org.nathandrew.mcmac-window", category: "IOHIDButtonTracker")

/// Detects physical button presses from Logitech MX mouse via IOHIDManager.
/// This bypasses firmware-level Cmd+Tab translation, allowing reliable button state detection.
public class IOHIDButtonTracker {

    // MARK: - Configuration

    let logitechVendorID: UInt32 = 0x046d  // Logitech vendor ID
    let gestureButtonUsagePage: UInt32 = 0x09  // Button page
    let gestureButtonUsageID: UInt32 = 0x03  // Button 3 (gesture button on MX)
    let auxiliaryButtonUsageRange: ClosedRange<UInt32> = 0x03...0x08

    // MARK: - State

    private var manager: IOHIDManager?
    var buttonDown = false

    // MARK: - Callbacks (injectable for tests)

    var onButtonDown: (() -> Void)?
    var onButtonUp: (() -> Void)?

    // MARK: - Initialization

    public init() {}

    // MARK: - Device Enumeration

    /// Starts monitoring Logitech devices for button presses.
    public func start() {
        guard manager == nil else { return }

        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        manager = mgr

        // Set up device matching for Logitech devices
        let matchingDict =
            [
                kIOHIDVendorIDKey: NSNumber(value: logitechVendorID)
            ] as [String: Any]

        IOHIDManagerSetDeviceMatching(mgr, matchingDict as CFDictionary)

        // Register value callback to receive button element events directly.
        IOHIDManagerRegisterInputValueCallback(
            mgr,
            { context, _, _, value in
                guard let ctx = context else { return }
                let tracker = Unmanaged<IOHIDButtonTracker>.fromOpaque(ctx).takeUnretainedValue()
                tracker.handleInputValue(value)
            },
            Unmanaged.passUnretained(self).toOpaque()
        )

        // Schedule with run loop
        IOHIDManagerScheduleWithRunLoop(
            mgr,
            CFRunLoopGetCurrent(),
            CFRunLoopMode.commonModes.rawValue as CFString
        )

        let result = IOHIDManagerOpen(mgr, 0)
        guard result == kIOReturnSuccess else {
            logger.error("IOHIDManagerOpen failed: \(result)")
            manager = nil
            return
        }

        logger.info("IOHIDButtonTracker started")
    }

    public func stop() {
        guard let mgr = manager else { return }
        IOHIDManagerClose(mgr, 0)
        manager = nil
        logger.info("IOHIDButtonTracker stopped")
    }

    deinit {
        stop()
    }

    // MARK: - Input Value Handling

    private func handleInputValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usageID = IOHIDElementGetUsage(element)
        let intValue = IOHIDValueGetIntegerValue(value)

        if usagePage == gestureButtonUsagePage {
            logger.debug(
                "HID button event usage=\(usageID, privacy: .public) value=\(intValue, privacy: .public)"
            )
        }

        processButtonEvent(usagePage: usagePage, usageID: usageID, intValue: intValue)
    }

    func processButtonEvent(usagePage: UInt32, usageID: UInt32, intValue: CFIndex) {
        guard usagePage == gestureButtonUsagePage else { return }

        // Some MX models expose the gesture button on usages other than 3.
        // Accept common auxiliary button usages so hardware works without vendor software.
        let isGestureCandidate =
            usageID == gestureButtonUsageID || auxiliaryButtonUsageRange.contains(usageID)
        guard isGestureCandidate else { return }

        updateButtonState(intValue != 0)
    }

    func updateButtonState(_ pressed: Bool) {
        guard pressed != buttonDown else { return }

        buttonDown = pressed

        if pressed {
            logger.debug("Gesture button DOWN")
            onButtonDown?()
        } else {
            logger.debug("Gesture button UP")
            onButtonUp?()
        }
    }
}
