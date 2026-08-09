import Carbon
import Foundation

final class VoiceHotKeyService {
    static let shortcutLabel = "⌃⌥V"
    static let shortcutPlainLabel = "Control + Option + V"

    private static let signature = OSType(0x44535056) // DSPV
    private static let hotKeyIDValue: UInt32 = 2

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    @discardableResult
    func register(action: @escaping () -> Void) -> Bool {
        unregister()
        self.action = action

        let target = GetEventDispatcherTarget()
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            target,
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }

                let service = Unmanaged<VoiceHotKeyService>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let readStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard readStatus == noErr,
                      hotKeyID.signature == VoiceHotKeyService.signature,
                      hotKeyID.id == VoiceHotKeyService.hotKeyIDValue
                else {
                    return OSStatus(eventNotHandledErr)
                }

                DispatchQueue.main.async {
                    service.action?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            unregister()
            return false
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.hotKeyIDValue)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(controlKey | optionKey),
            hotKeyID,
            target,
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            unregister()
            return false
        }

        NSLog("DeskPet: registered voice hotkey %@", Self.shortcutPlainLabel)
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        unregister()
    }
}
