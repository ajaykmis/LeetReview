import SwiftUI

struct DifficultyBadge: View {
    let difficulty: String

    private var color: Color {
        switch difficulty.lowercased() {
        case "easy":
            Theme.Colors.easy
        case "medium":
            Theme.Colors.medium
        case "hard":
            Theme.Colors.hard
        default:
            Theme.Colors.textSecondary
        }
    }

    var body: some View {
        Text(difficulty)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    HStack(spacing: Theme.Spacing.md) {
        DifficultyBadge(difficulty: "Easy")
        DifficultyBadge(difficulty: "Medium")
        DifficultyBadge(difficulty: "Hard")
    }
    .padding()
    .background(Theme.Colors.background)
}
