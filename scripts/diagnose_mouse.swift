#!/usr/bin/env swift
// Diagnostic: prints raw CGEvent button numbers and deltas.
// Run: swift scripts/diagnose_mouse.swift
// Press your gesture button and move the mouse; hit Ctrl+C when done.

import CoreGraphics
import Foundation

let mask: CGEventMask =
    (1 << CGEventType.otherMouseDown.rawValue)    |
    (1 << CGEventType.otherMouseUp.rawValue)      |
    (1 << CGEventType.otherMouseDragged.rawValue) |
    (1 << CGEventType.keyDown.rawValue)           |
    (1 << CGEventType.keyUp.rawValue)             |
    (1 << CGEventType.flagsChanged.rawValue)

guard let tap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: mask,
    callback: { _, type, event, _ -> Unmanaged<CGEvent>? in
        switch type {
        case .otherMouseDown:
            let btn = event.getIntegerValueField(.mouseEventButtonNumber)
            print("MOUSE DOWN  button=\(btn)")
        case .otherMouseUp:
            let btn = event.getIntegerValueField(.mouseEventButtonNumber)
            print("MOUSE UP    button=\(btn)")
        case .otherMouseDragged:
            let btn = event.getIntegerValueField(.mouseEventButtonNumber)
            let dx  = event.getDoubleValueField(.mouseEventDeltaX)
            if abs(dx) > 0 {
                print("MOUSE DRAG  button=\(btn)  dx=\(dx)")
            }
        case .keyDown:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags   = event.flags.rawValue
            print("KEY DOWN    keyCode=\(keyCode)  flags=0x\(String(flags, radix: 16))")
        case .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            print("KEY UP      keyCode=\(keyCode)")
        case .flagsChanged:
            let flags = event.flags.rawValue
            print("FLAGS       0x\(String(flags, radix: 16))")
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    },
    userInfo: nil
) else {
    print("ERROR: CGEventTap creation failed.")
    print("Grant Accessibility permission to Terminal in System Settings → Privacy & Security → Accessibility.")
    exit(1)
}

let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("Listening for mouse + keyboard events. Press and hold your gesture button, move the mouse, then Ctrl+C.\n")
CFRunLoopRun()
