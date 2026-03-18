import AppKit
@preconcurrency import ApplicationServices
import Foundation

enum CaretLocator {
    static func caretPoint() -> CGPoint? {
        guard isTrusted(promptIfNeeded: false) else { return nil }

        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusedErr = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusedErr == .success, let focusedElement = focused else { return nil }

        let element = focusedElement as! AXUIElement
        var selectedRangeValue: CFTypeRef?
        let rangeErr = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue)
        guard rangeErr == .success, let selectedRangeValue else { return nil }
        guard CFGetTypeID(selectedRangeValue) == AXValueGetTypeID() else { return nil }
        let rangeAXValue = selectedRangeValue as! AXValue

        var rectValue: CFTypeRef?
        let rectErr = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeAXValue,
            &rectValue
        )
        guard rectErr == .success, let rectValue else { return nil }
        guard CFGetTypeID(rectValue) == AXValueGetTypeID() else { return nil }
        let rectAXValue = rectValue as! AXValue

        var rect = CGRect.zero
        guard AXValueGetValue(rectAXValue, .cgRect, &rect) else { return nil }

        if rect.isNull || rect.isEmpty {
            return nil
        }

        return CGPoint(x: rect.minX, y: rect.maxY)
    }

    static func isTrusted(promptIfNeeded: Bool) -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options: CFDictionary = [promptKey: promptIfNeeded] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
