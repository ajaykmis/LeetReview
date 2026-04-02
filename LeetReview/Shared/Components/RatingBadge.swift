import SwiftUI

/// A small capsule badge displaying a problem's community difficulty rating.
/// Color-coded by rating tier, similar to Codeforces rating brackets.
struct RatingBadge: View {
    let rating: Int

    private var color: Color {
        switch rating {
        case ..<1200:
            Color(lightHex: 0x6B7280, darkHex: 0x9CA3AF) // gray — beginner
        case 1200..<1400:
            Theme.Colors.easy // green
        case 1400..<1600:
            Color(lightHex: 0x0891B2, darkHex: 0x67E8F9) // cyan/teal
        case 1600..<1900:
            Color(lightHex: 0x2563EB, darkHex: 0x89B4FA) // blue
        case 1900..<2100:
            Color(lightHex: 0x7C3AED, darkHex: 0xCBA6F7) // purple
        case 2100..<2400:
            Theme.Colors.medium // orange
        default:
            Theme.Colors.hard // red — expert (2400+)
        }
    }

    var body: some View {
        Text("R: \(rating)")
            .font(.caption2.bold().monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    HStack(spacing: Theme.Spacing.sm) {
        RatingBadge(rating: 1100)
        RatingBadge(rating: 1350)
        RatingBadge(rating: 1500)
        RatingBadge(rating: 1750)
        RatingBadge(rating: 2000)
        RatingBadge(rating: 2200)
        RatingBadge(rating: 2500)
    }
    .padding()
    .background(Theme.Colors.background)
}
