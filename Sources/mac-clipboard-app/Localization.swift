import Foundation

@MainActor
func L(_ key: String) -> String {
    LocalizationCenter.shared.bundle.localizedString(forKey: key, value: nil, table: nil)
}
