import AppKit
import Carbon

private let hkLogPath = "/tmp/mcmac-window.log"
private func hlog(_ msg: String) {
    let line = "\(Date()) [HK] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if let handle = FileHandle(forWritingAtPath: hkLogPath) {
            handle.seekToEndOfFile(); handle.write(data); handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: hkLogPath, contents: data)
        }
    }
}

// WindowAction is defined in WindowAction.swift (no Carbon dependency)

private struct Binding {
    let keyCode: UInt32
    let carbonMods: UInt32
    let action: WindowAction
    let display: String
}

private enum Key {
    static let leftArrow:  UInt32 = 0x7B
    static let rightArrow: UInt32 = 0x7C
    static let downArrow:  UInt32 = 0x7D
    static let upArrow:    UInt32 = 0x7E
    static let `return`:   UInt32 = 0x24
    static let space:      UInt32 = 0x31
}

private let C  = UInt32(controlKey)
private let O  = UInt32(optionKey)
private let Cm = UInt32(cmdKey)
private let S  = UInt32(shiftKey)

private let kHotKeySignature: OSType = 0x6D776B6D

class HotkeyManager {

    static let shared = HotkeyManager()
    private init() {}

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?

    private let bindings: [Binding] = [
        Binding(keyCode: Key.leftArrow,  carbonMods: C|O,       action: .leftHalf,       display: "⌃⌥ ←      Left Half"),
        Binding(keyCode: Key.rightArrow, carbonMods: C|O,       action: .rightHalf,      display: "⌃⌥ →      Right Half"),
        Binding(keyCode: Key.upArrow,    carbonMods: C|O,       action: .topHalf,        display: "⌃⌥ ↑      Top Half"),
        Binding(keyCode: Key.downArrow,  carbonMods: C|O,       action: .bottomHalf,     display: "⌃⌥ ↓      Bottom Half"),
        Binding(keyCode: Key.leftArrow,  carbonMods: C|O|Cm,    action: .topLeft,        display: "⌃⌥⌘ ←     Top Left"),
        Binding(keyCode: Key.rightArrow, carbonMods: C|O|Cm,    action: .topRight,       display: "⌃⌥⌘ →     Top Right"),
        Binding(keyCode: Key.leftArrow,  carbonMods: C|O|S,     action: .bottomLeft,     display: "⌃⌥⇧ ←     Bottom Left"),
        Binding(keyCode: Key.rightArrow, carbonMods: C|O|S,     action: .bottomRight,    display: "⌃⌥⇧ →     Bottom Right"),
        Binding(keyCode: Key.return,     carbonMods: C|O,       action: .maximize,       display: "⌃⌥ ↩      Maximize"),
        Binding(keyCode: Key.space,      carbonMods: C|O,       action: .center,         display: "⌃⌥ Space  Center"),
        Binding(keyCode: Key.leftArrow,  carbonMods: C|O|Cm|S,  action: .nextThirdLeft,   display: "⌃⌥⌘⇧ ←   Third Left"),
        Binding(keyCode: Key.rightArrow, carbonMods: C|O|Cm|S,  action: .nextThirdRight,  display: "⌃⌥⌘⇧ →   Third Right"),
        Binding(keyCode: Key.upArrow,    carbonMods: C|O|Cm,    action: .leftTwoThirds,   display: "⌃⌥⌘ ↑     Left Two Thirds"),
        Binding(keyCode: Key.downArrow,  carbonMods: C|O|Cm,    action: .rightTwoThirds,  display: "⌃⌥⌘ ↓     Right Two Thirds")
    ]

    func register() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, inEvent, inUserData -> OSStatus in
                guard let event = inEvent, let userData = inUserData else {
                    return OSStatus(eventNotHandledErr)
                }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return mgr.handleCarbonHotKey(event: event)
            },
            1, &eventSpec, selfPtr, &eventHandlerRef
        )

        hlog("registering \(bindings.count) hotkeys")
        for (index, binding) in bindings.enumerated() {
            let id = EventHotKeyID(signature: kHotKeySignature, id: UInt32(index))
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                binding.keyCode, binding.carbonMods, id,
                GetApplicationEventTarget(), 0, &ref
            )
            if status != noErr {
                hlog("FAILED to register hotkey \(index) (\(binding.display)) — OSStatus \(status)")
            } else {
                hlog("registered hotkey \(index): \(binding.display)")
            }
            hotKeyRefs.append(ref)
        }
        hlog("hotkey registration complete")
    }

    func unregister() {
        for ref in hotKeyRefs { if let r = ref { UnregisterEventHotKey(r) } }
        hotKeyRefs.removeAll()
        if let h = eventHandlerRef { RemoveEventHandler(h); eventHandlerRef = nil }
    }

    private func handleCarbonHotKey(event: EventRef) -> OSStatus {
        hlog("Carbon hotkey event received")
        var hotKeyID = EventHotKeyID()
        let err = GetEventParameter(
            event, UInt32(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID), nil,
            MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
        )
        guard err == noErr, hotKeyID.signature == kHotKeySignature else {
            hlog("hotkey event parse failed — err=\(err) sig=\(hotKeyID.signature)")
            return OSStatus(eventNotHandledErr)
        }
        let index = Int(hotKeyID.id)
        guard index < bindings.count else { return OSStatus(eventNotHandledErr) }
        hlog("dispatching action \(bindings[index].action.rawValue)")
        WindowMover.shared.move(action: bindings[index].action)
        return noErr
    }

    func shortcutDescriptions() -> [String] { bindings.map { $0.display } }
}
