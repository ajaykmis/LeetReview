import SwiftUI

enum Theme {
    enum Colors {
        static let background = Color(hex: 0x1E1E2E)
        static let card = Color(hex: 0x2D2D3F)
        static let text = Color(hex: 0xCDD6F4)
        static let textSecondary = Color(hex: 0xA6ADC8)
        static let accent = Color(hex: 0x89B4FA)
        static let easy = Color(hex: 0xA6E3A1)
        static let medium = Color(hex: 0xF9E2AF)
        static let hard = Color(hex: 0xF38BA8)
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
