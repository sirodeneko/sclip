import AppKit
import Carbon.HIToolbox
import SwiftUI

struct KeyCaptureView: NSViewRepresentable {
    @Binding var hotKey: HotKeyManager.HotKey
    @Binding var requestFocus: Bool
    @Binding var isCapturing: Bool

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onHotKeyChange = context.coordinator.onHotKeyChange(_:)
        view.onCancel = context.coordinator.onCancel
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.isCapturing = isCapturing
        if requestFocus, let window = nsView.window {
            window.makeFirstResponder(nsView)
            requestFocus = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hotKey: $hotKey, isCapturing: $isCapturing)
    }

    final class Coordinator {
        var hotKey: Binding<HotKeyManager.HotKey>
        var isCapturing: Binding<Bool>

        init(hotKey: Binding<HotKeyManager.HotKey>, isCapturing: Binding<Bool>) {
            self.hotKey = hotKey
            self.isCapturing = isCapturing
        }

        func onHotKeyChange(_ newHotKey: HotKeyManager.HotKey) {
            hotKey.wrappedValue = newHotKey
            isCapturing.wrappedValue = false
        }

        func onCancel() {
            isCapturing.wrappedValue = false
        }
    }
}

final class KeyCaptureNSView: NSView {
    var onHotKeyChange: ((HotKeyManager.HotKey) -> Void)?
    var onCancel: (() -> Void)?
    var isCapturing: Bool = false

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isCapturing else { return }

        if event.keyCode == 53 {
            onCancel?()
            return
        }

        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !flags.isEmpty else { return }

        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }

        let hk = HotKeyManager.HotKey(keyCode: UInt32(event.keyCode), modifiers: carbon)
        onHotKeyChange?(hk)
    }
}
