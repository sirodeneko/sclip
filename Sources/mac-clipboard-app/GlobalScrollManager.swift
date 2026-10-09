import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Global keyboard -> horizontal scroll.
///
/// Installs a HID-level event tap that works in *any* foreground app. When
/// the configured shortcut (default ⇧←/⇧→) is pressed, the key is swallowed
/// and replaced by a system-level horizontal scrollWheel event delivered at
/// the current cursor location — the same continuous, pixel-based event a
/// two-finger trackpad swipe produces — letting the user pan wide pages and
/// tables without reaching for the scroll bar.
///
/// If the focused UI element is an editable text control, the key passes
/// through untouched so normal text selection/caret movement keeps working.
///
/// Requires Accessibility permission (required to create the tap).
@MainActor
final class GlobalScrollManager {
    private let preferences: PreferencesModel
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(preferences: PreferencesModel) {
        self.preferences = preferences
    }

    /// No-op if already running. Safe to call repeatedly after permission is
    /// granted; the tap is (re)created once Accessibility allows it.
    func start() {
        guard eventTap == nil else { return }

        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)
        )

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: globalScrollCallback,
            userInfo: userInfo
        ) else {
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    func stop() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: Event handling (runs on the main run loop)

    /// - Returns: true to pass the key through, false to consume it.
    fileprivate func handle(_ info: KeyInfo) -> Bool {
        // Re-enable the tap if the system disabled it.
        if info.typeRaw == CGEventType.tapDisabledByTimeout.rawValue
            || info.typeRaw == CGEventType.tapDisabledByUserInput.rawValue {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return true
        }

        guard let match = shortcutMatch(keyCode: info.keyCode, mods: info.carbonMods) else {
            return true
        }

        // In a text field/area, let the key do its normal job.
        if isFocusedElementEditableText() {
            return true
        }

        postHorizontalScroll(direction: match.direction, fast: match.fast)
        return false // consume the original key
    }

    private func shortcutMatch(keyCode: UInt32, mods: UInt32) -> (direction: Int, fast: Bool)? {
        if let m = matchOne(keyCode, mods, preferences.hScrollLeft, direction: -1) { return m }
        if let m = matchOne(keyCode, mods, preferences.hScrollRight, direction: 1) { return m }
        return nil
    }

    private func matchOne(
        _ keyCode: UInt32,
        _ mods: UInt32,
        _ hotKey: HotKeyManager.HotKey,
        direction: Int
    ) -> (direction: Int, fast: Bool)? {
        guard keyCode == hotKey.keyCode else { return nil }
        if mods == hotKey.modifiers { return (direction, false) }
        // Extra Option (when Option isn't already part of the shortcut) = fast.
        if hotKey.modifiers & UInt32(optionKey) == 0,
           mods == (hotKey.modifiers | UInt32(optionKey)) {
            return (direction, true)
        }
        return nil
    }

    // MARK: scrollWheel synthesis

    private func postHorizontalScroll(direction: Int, fast: Bool) {
        // Per key-repeat tick. Negated because positive scrollWheel delta
        // pans content right (browse left).
        let step = fast ? 48 : 16
        let delta = -Int32(step * direction)

        guard let scroll = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: 0,
            wheel2: delta,
            wheel3: 0
        ) else { return }

        scroll.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        scroll.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(delta))

        // Route under the cursor, wherever it is in the foreground app.
        scroll.location = NSEvent.mouseLocation

        // Post at the HID layer — the path browsers (e.g. Chrome) reliably
        // handle. Note: when a global scroll enhancer (such as Mac Mouse Fix)
        // is running, it also sees the event and may move the pointer; this
        // is the accepted trade-off for the scroll to work everywhere.
        scroll.post(tap: .cghidEventTap)
    }

    // MARK: Focused-element text check

    /// True if the system-wide focused element is an editable text control.
    private func isFocusedElementEditableText() -> Bool {
        var focusedRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(),
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard focusedResult == .success, let focused = focusedRef else {
            // Can't determine focus; allow scrolling rather than blocking.
            return false
        }
        // Contract of kAXFocusedUIElementAttribute: the value is an AXUIElement.
        let element = focused as! AXUIElement

        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleRef
        ) == .success, let role = roleRef as? String else {
            return false
        }

        return Self.editableTextRoles.contains(role)
    }

    private static let editableTextRoles: Set<String> = [
        kAXTextFieldRole,
        kAXTextAreaRole,
        "AXSearchField",
    ]
}

private struct KeyInfo: Sendable {
    let typeRaw: UInt32
    let keyCode: UInt32
    let carbonMods: UInt32
}

private let globalScrollCallback: CGEventTapCallBack = { _, type, cgEvent, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(cgEvent) }

    // Read only Sendable scalar data before crossing into the MainActor
    // domain — CGEvent itself is not Sendable.
    let keyCode = UInt32(cgEvent.getIntegerValueField(.keyboardEventKeycode))
    let eventFlags = cgEvent.flags
    var carbon: UInt32 = 0
    if eventFlags.contains(.maskCommand) { carbon |= UInt32(cmdKey) }
    if eventFlags.contains(.maskShift) { carbon |= UInt32(shiftKey) }
    if eventFlags.contains(.maskAlternate) { carbon |= UInt32(optionKey) }
    if eventFlags.contains(.maskControl) { carbon |= UInt32(controlKey) }
    let info = KeyInfo(typeRaw: type.rawValue, keyCode: keyCode, carbonMods: carbon)

    // UnsafeMutableRawPointer is not Sendable; ferry it as an integer.
    let userData = UInt(bitPattern: userInfo)

    // The tap source is on the main run loop, so this runs on the main thread.
    let passThrough = MainActor.assumeIsolated {
        guard let ptr = UnsafeMutableRawPointer(bitPattern: userData) else { return true }
        let manager = Unmanaged<GlobalScrollManager>.fromOpaque(ptr).takeUnretainedValue()
        return manager.handle(info)
    }
    return passThrough ? Unmanaged.passUnretained(cgEvent) : nil
}
