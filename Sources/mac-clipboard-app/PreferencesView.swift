import SwiftUI

struct PreferencesView: View {
    @ObservedObject var preferences: PreferencesModel
    var onHotKeyChanged: (HotKeyManager.HotKey) -> Void
    @ObservedObject private var i18n = LocalizationCenter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("settings.hotkey"))
                Spacer()
                HotKeyCaptureBox(
                    hotKey: $preferences.hotKey,
                    accessibilityLabel: L("settings.hotkey_capture_label")
                )
            }

            Toggle(L("settings.auto_paste"), isOn: $preferences.autoPasteAfterSelection)

            Toggle(L("settings.copy_file_path"), isOn: $preferences.enableCopyFilePath)

            HStack {
                Text(L("settings.history_limit"))
                Spacer()
                Stepper(value: $preferences.historyLimit, in: 10...5000, step: 10) {
                    Text("\(preferences.historyLimit)")
                        .frame(minWidth: 64, alignment: .trailing)
                }
                .frame(width: 180)
            }

            HStack {
                Text(L("settings.language"))
                Spacer()
                Picker("", selection: $i18n.language) {
                    Text(L("settings.language.system")).tag(AppLanguage.system)
                    Text(L("settings.language.en")).tag(AppLanguage.en)
                    Text(L("settings.language.zhHans")).tag(AppLanguage.zhHans)
                }
                .labelsHidden()
                .frame(width: 180)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L("settings.hscroll_section"))
                    .font(.system(size: 13, weight: .semibold))

                HStack {
                    Text(L("settings.hscroll_left"))
                    Spacer()
                    HotKeyCaptureBox(
                        hotKey: $preferences.hScrollLeft,
                        accessibilityLabel: L("settings.hscroll_capture_label"),
                        width: 150
                    )
                }

                HStack {
                    Text(L("settings.hscroll_right"))
                    Spacer()
                    HotKeyCaptureBox(
                        hotKey: $preferences.hScrollRight,
                        accessibilityLabel: L("settings.hscroll_capture_label"),
                        width: 150
                    )
                }

                Text(L("settings.hscroll_desc"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 420, height: 410)
        .onChange(of: preferences.hotKey) { newValue in
            onHotKeyChanged(newValue)
        }
    }
}

private struct HotKeyCaptureBox: View {
    @Binding var hotKey: HotKeyManager.HotKey
    let accessibilityLabel: String
    var width: CGFloat = 180

    @State private var requestHotKeyFocus: Bool = false
    @State private var isCapturingHotKey: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isCapturingHotKey ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isCapturingHotKey ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.12), lineWidth: 1)
                )

            HStack(spacing: 8) {
                Text(isCapturingHotKey ? L("settings.hotkey_recording") : HotKeyDisplay.string(for: hotKey))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                Spacer(minLength: 0)
            }

            KeyCaptureView(hotKey: $hotKey, requestFocus: $requestHotKeyFocus, isCapturing: $isCapturingHotKey)
                .opacity(0.01)
        }
        .frame(width: width, height: 30)
        .accessibilityLabel(accessibilityLabel)
        .contentShape(Rectangle())
        .onTapGesture {
            isCapturingHotKey = true
            requestHotKeyFocus = true
        }
    }
}
