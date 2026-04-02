import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: opacity
        )
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init(lightHex: UInt, darkHex: UInt, lightOpacity: Double = 1.0, darkOpacity: Double = 1.0) {
        self.init(uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(hex: darkHex, opacity: darkOpacity)
            }
            return UIColor(hex: lightHex, opacity: lightOpacity)
        })
    }
}
