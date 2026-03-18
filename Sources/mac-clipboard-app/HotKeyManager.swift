import Carbon.HIToolbox
import Foundation

@MainActor
final class HotKeyManager {
    struct HotKey: Hashable {
        var keyCode: UInt32
        var modifiers: UInt32
    }

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var hotKeyID: EventHotKeyID?

    var onTrigger: (() -> Void)?

    func register(_ hotKey: HotKey) {
        unregister()

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                manager.onTrigger?()
            }
            return noErr
        }

        let userData = Unmanaged.passUnretained(self).toOpaque()
        var handlerRef: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventSpec, userData, &handlerRef)
        self.handlerRef = handlerRef

        let id = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: 0x434C4950)), id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            self.hotKeyRef = ref
            self.hotKeyID = id
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        self.hotKeyID = nil
    }
}
