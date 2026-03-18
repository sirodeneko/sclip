import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case en = "en"
    case zhHans = "zh-Hans"

    var id: String { rawValue }

    var lprojName: String? {
        switch self {
        case .system:
            return nil
        case .en:
            return "en"
        case .zhHans:
            return "zh-Hans"
        }
    }
}
