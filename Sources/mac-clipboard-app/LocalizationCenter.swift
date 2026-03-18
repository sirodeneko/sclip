import Combine
import Foundation

@MainActor
final class LocalizationCenter: ObservableObject {
    static let shared = LocalizationCenter()

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Keys.language)
        }
    }

    var bundle: Bundle {
        guard let lproj = language.lprojName else { return Bundle.module }
        guard let url = Bundle.module.url(forResource: lproj, withExtension: "lproj"),
              let bundle = Bundle(url: url) else { return Bundle.module }
        return bundle
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.language),
           let value = AppLanguage(rawValue: raw) {
            self.language = value
        } else {
            self.language = .system
        }
    }

    private enum Keys {
        static let language = "settings.language"
    }
}
