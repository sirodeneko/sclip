import SwiftUI

struct PermissionsView: View {
    @ObservedObject var model: PermissionStatusModel
    var onClose: () -> Void
    @ObservedObject private var i18n = LocalizationCenter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("permissions.header"))
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                statusPill
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L("permissions.desc"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(L("permissions.step1"))
                    Text(L("permissions.step2"))
                    Text(L("permissions.step3"))
                }
                .font(.system(size: 12))
                .foregroundColor(.primary.opacity(0.85))
            }

            HStack(spacing: 10) {
                Button(L("permissions.open_settings")) {
                    PermissionsCenter.openAccessibilitySettings()
                }
                .keyboardShortcut(.defaultAction)

                Button(L("permissions.check_again")) {
                    model.refresh()
                    if model.accessibilityGranted {
                        onClose()
                    }
                }

                Spacer()

                Button(L("permissions.close")) {
                    onClose()
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 520, height: 220)
        .onAppear {
            model.refresh()
        }
    }

    private var statusPill: some View {
        let text = model.accessibilityGranted ? L("permissions.granted") : L("permissions.not_granted")
        let color = model.accessibilityGranted ? Color.green.opacity(0.18) : Color.orange.opacity(0.18)
        return Text(text)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}
