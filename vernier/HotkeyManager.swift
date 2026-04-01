import Carbon

class HotkeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotkeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var callbacks: [UInt32: () -> Void] = [:]
    private var nextHotkeyID: UInt32 = 1
    private let signature = OSType(0x5652_4E52) // "VRNR"

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> UInt32? {
        ensureEventHandlerInstalled()

        let hotkeyIDValue = nextHotkeyID
        nextHotkeyID += 1

        let hotkeyID = EventHotKeyID(
            signature: signature,
            id: hotkeyIDValue
        )

        var hotkeyRef: EventHotKeyRef?
        let regStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        guard regStatus == noErr, let hotkeyRef else {
            print("Failed to register hotkey: \(regStatus)")
            return nil
        }

        hotkeyRefs[hotkeyIDValue] = hotkeyRef
        callbacks[hotkeyIDValue] = handler
        return hotkeyIDValue
    }

    func unregister(hotkeyID: UInt32) {
        if let ref = hotkeyRefs.removeValue(forKey: hotkeyID) {
            UnregisterEventHotKey(ref)
        }
        callbacks.removeValue(forKey: hotkeyID)
        if hotkeyRefs.isEmpty, let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    func unregisterAll() {
        for hotkeyID in Array(hotkeyRefs.keys) {
            unregister(hotkeyID: hotkeyID)
        }
    }

    private func ensureEventHandlerInstalled() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, inEvent, userData) -> OSStatus in
                guard let inEvent, let userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                var hotkeyID = EventHotKeyID()
                let paramStatus = GetEventParameter(
                    inEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )

                guard paramStatus == noErr else { return noErr }
                manager.callbacks[hotkeyID.id]?()
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )

        if status != noErr {
            print("Failed to install hotkey event handler: \(status)")
        }
    }

    deinit {
        unregisterAll()
    }
}
