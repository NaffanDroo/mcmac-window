import IOKit
import OSLog

private let logger = Logger(subsystem: "org.nathandrew.mcmac-window", category: "IOHIDButtonTracker")

private let kLogitechVendorID = 0x046D
private let kButtonUsagePage  = UInt32(0x09)   // kHIDPage_Button
private let kUDKeyUsagePage   = "gestureButtonUsagePage"
private let kUDKeyUsageID     = "gestureButtonUsageID"

public class IOHIDButtonTracker {

    public var onButtonDown: () -> Void = {}
    public var onButtonUp:   () -> Void = {}

    private var hidManager: IOHIDManager?

    public init() {}

    deinit { stop() }

    // MARK: - Lifecycle

    public func start() {
        guard hidManager == nil else { return }
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(
            mgr,
            [kIOHIDVendorIDKey as String: kLogitechVendorID] as CFDictionary
        )
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(mgr, { ctx, _, _, value in
            guard let ctx = ctx else { return }
            let tracker   = Unmanaged<IOHIDButtonTracker>.fromOpaque(ctx).takeUnretainedValue()
            let element   = IOHIDValueGetElement(value)
            let usagePage = IOHIDElementGetUsagePage(element)
            let usageID   = IOHIDElementGetUsage(element)
            let intValue  = IOHIDValueGetIntegerValue(value)
            tracker.processButtonEvent(usagePage: usagePage, usageID: usageID, intValue: intValue)
        }, ptr)
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = mgr
        logger.info("IOHIDButtonTracker started")
    }

    public func stop() {
        guard let mgr = hidManager else { return }
        IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
        hidManager = nil
        logger.info("IOHIDButtonTracker stopped")
    }

    public func resetCalibration() {
        UserDefaults.standard.removeObject(forKey: kUDKeyUsagePage)
        UserDefaults.standard.removeObject(forKey: kUDKeyUsageID)
        logger.info("IOHIDButtonTracker calibration reset")
    }

    // MARK: - Event processing (internal for testing)

    func processButtonEvent(usagePage: UInt32, usageID: UInt32, intValue: CFIndex) {
        guard usagePage == kButtonUsagePage else { return }

        let storedPage  = UserDefaults.standard.object(forKey: kUDKeyUsagePage)  as? Int
        let storedUsage = UserDefaults.standard.object(forKey: kUDKeyUsageID)    as? Int

        if storedPage == nil || storedUsage == nil {
            guard intValue == 1 else { return }
            UserDefaults.standard.set(Int(usagePage), forKey: kUDKeyUsagePage)
            UserDefaults.standard.set(Int(usageID),   forKey: kUDKeyUsageID)
            logger.info("Calibrated gesture button: page=\(usagePage) id=\(usageID)")
            onButtonDown()
            return
        }

        guard Int(usagePage) == storedPage, Int(usageID) == storedUsage else { return }
        if intValue == 1 { onButtonDown() } else { onButtonUp() }
    }
}
