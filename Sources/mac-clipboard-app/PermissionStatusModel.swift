import Foundation

@MainActor
final class PermissionStatusModel: ObservableObject {
    @Published private(set) var accessibilityGranted: Bool = false

    func refresh() {
        accessibilityGranted = PermissionsCenter.isAccessibilityGranted()
    }
}

