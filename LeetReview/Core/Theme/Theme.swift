import SwiftUI
import Observation

@Observable
@MainActor
final class ThemeManager {
    enum Preference: String {
        case light
        case dark
    }

    private static let preferenceKey = "theme_preference"

    var preferredTheme: Preference {
        didSet {
            UserDefaults.standard.set(preferredTheme.rawValue, forKey: Self.preferenceKey)
        }
    }

    init() {
        let storedValue = UserDefaults.standard.string(forKey: Self.preferenceKey)
        self.preferredTheme = Preference(rawValue: storedValue ?? "") ?? .dark
    }

    var isDarkModeEnabled: Bool {
        get { preferredTheme == .dark }
        set { preferredTheme = newValue ? .dark : .light }
    }

    var preferredColorScheme: ColorScheme {
        preferredTheme == .dark ? .dark : .light
    }

    var toolbarColorScheme: ColorScheme {
        preferredColorScheme
    }
}

enum Theme {
    enum Colors {
        static let background = Color(lightHex: 0xF5F7FB, darkHex: 0x1E1E2E)
        static let card = Color(lightHex: 0xFFFFFF, darkHex: 0x2D2D3F)
        static let text = Color(lightHex: 0x1F2937, darkHex: 0xCDD6F4)
        static let textSecondary = Color(lightHex: 0x64748B, darkHex: 0xA6ADC8)
        static let accent = Color(lightHex: 0x2563EB, darkHex: 0x89B4FA)
        static let easy = Color(lightHex: 0x16A34A, darkHex: 0xA6E3A1)
        static let medium = Color(lightHex: 0xD97706, darkHex: 0xF9E2AF)
        static let hard = Color(lightHex: 0xDC2626, darkHex: 0xF38BA8)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    static let cornerRadius: CGFloat = 16
}
