import Carbon
import AppKit

nonisolated(unsafe) private var _globalHotKeyHandlers: [UInt32: () -> Void] = [:]
nonisolated(unsafe) private var _nextHotKeyID: UInt32 = 1
nonisolated(unsafe) private var _carbonEventHandlerRef: EventHandlerRef?

private func carbonHotKeyEventHandler(
    _: EventHandlerCallRef?,
    event: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let err = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard err == noErr else { return OSStatus(eventNotHandledErr) }

    let id = hotKeyID.id
    if let handler = _globalHotKeyHandlers[id] {
        DispatchQueue.main.async { handler() }
        return noErr
    }
    return OSStatus(eventNotHandledErr)
}

final class GlobalHotKey {
    nonisolated(unsafe) private let hotKeyRef: EventHotKeyRef
    private let hotKeyID: UInt32

    init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        let id = _nextHotKeyID
        _nextHotKeyID += 1

        if _carbonEventHandlerRef == nil {
            var eventSpec = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            InstallEventHandler(
                GetApplicationEventTarget(),
                carbonHotKeyEventHandler,
                1,
                &eventSpec,
                nil,
                &_carbonEventHandlerRef
            )
        }

        var hkID = EventHotKeyID()
        hkID.signature = OSType(0x5354_4B59)
        hkID.id = id

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hkID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let hotKey = ref else { return nil }

        self.hotKeyRef = hotKey
        self.hotKeyID = id
        _globalHotKeyHandlers[id] = handler
    }

    deinit {
        UnregisterEventHotKey(hotKeyRef)
        _globalHotKeyHandlers.removeValue(forKey: hotKeyID)
    }
}
