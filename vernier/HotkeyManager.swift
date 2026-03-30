import Carbon
import AppKit

class HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var callback: (() -> Void)?

    // Using a static to bridge the C callback to Swift
    private static var instance: HotkeyManager?

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        callback = handler
        HotkeyManager.instance = self

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, inEvent, _) -> OSStatus in
                HotkeyManager.instance?.callback?()
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard status == noErr else {
            print("Failed to install hotkey event handler: \(status)")
            return
        }

        let hotkeyID = EventHotKeyID(
            signature: OSType(0x5652_4E52), // "VRNR"
            id: 1
        )

        let regStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if regStatus != noErr {
            print("Failed to register hotkey: \(regStatus)")
        }
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        HotkeyManager.instance = nil
    }

    deinit {
        unregister()
    }
}
