import Carbon
import Combine
import Foundation

final class GlobalHotKeyService: ObservableObject {
    struct ShortcutPreset: Identifiable, Equatable {
        let id: String
        let symbolLabel: String
        let plainLabel: String
        let keyCode: UInt32
        let modifiers: UInt32

        var displayLabel: String {
            "\(plainLabel)（\(symbolLabel)）"
        }

        static let presets: [ShortcutPreset] = [
            ShortcutPreset(
                id: "control-shift-space",
                symbolLabel: "⌃⇧Space",
                plainLabel: "Control + Shift + Space",
                keyCode: UInt32(kVK_Space),
                modifiers: UInt32(controlKey | shiftKey)
            ),
            ShortcutPreset(
                id: "control-option-d",
                symbolLabel: "⌃⌥D",
                plainLabel: "Control + Option + D",
                keyCode: UInt32(kVK_ANSI_D),
                modifiers: UInt32(controlKey | optionKey)
            ),
            ShortcutPreset(
                id: "control-option-space",
                symbolLabel: "⌃⌥Space",
                plainLabel: "Control + Option + Space",
                keyCode: UInt32(kVK_Space),
                modifiers: UInt32(controlKey | optionKey)
            )
        ]

        static let fallback = presets[0]
    }

    private enum DefaultsKey {
        // v2 intentionally ignores the older ⌃⇧D default so existing 0.2.x
        // installations migrate to a less ambiguous shortcut automatically.
        static let shortcutPreset = "DeskPet.hotkey.preset.v2"
    }

    private static let signature = OSType(0x44535054) // DSPT
    private static let hotKeyIDValue: UInt32 = 1

    @Published private(set) var isRegistered = false
    @Published private(set) var statusMessage = "尚未註冊"
    @Published private(set) var activeShortcutLabel = ShortcutPreset.fallback.symbolLabel
    @Published private(set) var activeShortcutPlainLabel = ShortcutPreset.fallback.plainLabel

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var action: (() -> Void)?
    private var selectedPreset: ShortcutPreset

    init() {
        let savedID = UserDefaults.standard.string(forKey: DefaultsKey.shortcutPreset)
        selectedPreset = Self.preset(id: savedID) ?? .fallback
        syncPublishedLabels()
    }

    var availablePresets: [ShortcutPreset] {
        ShortcutPreset.presets
    }

    var selectedPresetID: String {
        selectedPreset.id
    }

    @discardableResult
    func register(action: @escaping () -> Void) -> Bool {
        self.action = action
        return registerCurrentPreset()
    }

    @discardableResult
    func reRegister() -> Bool {
        registerCurrentPreset()
    }

    @discardableResult
    func selectPreset(id: String) -> Bool {
        guard let preset = Self.preset(id: id) else { return false }
        selectedPreset = preset
        syncPublishedLabels()
        UserDefaults.standard.set(preset.id, forKey: DefaultsKey.shortcutPreset)
        return registerCurrentPreset()
    }

    func triggerForTesting() {
        action?()
    }

    func unregister() {
        unregisterHotKeyObjects()
        isRegistered = false
        statusMessage = "尚未註冊"
    }

    private func syncPublishedLabels() {
        activeShortcutLabel = selectedPreset.symbolLabel
        activeShortcutPlainLabel = selectedPreset.plainLabel
    }

    private func registerCurrentPreset() -> Bool {
        unregisterHotKeyObjects()

        guard action != nil else {
            isRegistered = false
            statusMessage = "沒有可執行的快速記事動作"
            return false
        }

        // Bind the Carbon hotkey handler to this application instead of the
        // process-wide event dispatcher. This is more deterministic for an
        // LSUIElement/accessory app on newer macOS releases.
        let target = GetApplicationEventTarget()

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

                let service = Unmanaged<GlobalHotKeyService>
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
                      hotKeyID.signature == GlobalHotKeyService.signature,
                      hotKeyID.id == GlobalHotKeyService.hotKeyIDValue
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
            isRegistered = false
            statusMessage = "事件處理器註冊失敗（\(handlerStatus)）"
            NSLog("DeskPet: failed to install global hotkey handler (%d)", handlerStatus)
            unregisterHotKeyObjects()
            return false
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: Self.hotKeyIDValue
        )

        let registerStatus = RegisterEventHotKey(
            selectedPreset.keyCode,
            selectedPreset.modifiers,
            hotKeyID,
            target,
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            isRegistered = false
            statusMessage = "\(selectedPreset.displayLabel) 註冊失敗（\(registerStatus)）"
            NSLog("DeskPet: failed to register global hotkey %@ (%d)", selectedPreset.symbolLabel, registerStatus)
            unregisterHotKeyObjects()
            return false
        }

        syncPublishedLabels()
        isRegistered = true
        statusMessage = "已註冊 \(selectedPreset.displayLabel)"
        NSLog("DeskPet: registered global hotkey %@", selectedPreset.displayLabel)
        return true
    }

    private func unregisterHotKeyObjects() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private static func preset(id: String?) -> ShortcutPreset? {
        guard let id else { return nil }
        return ShortcutPreset.presets.first { $0.id == id }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
