import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String?

    init(
        title: String,
        value: String,
        color: Color = Theme.Colors.accent,
        icon: String? = nil
    ) {
        self.title = title
        self.value = value
        self.color = color
        self.icon = icon
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

#Preview {
    HStack {
        StatCard(title: "Easy", value: "120", color: Theme.Colors.easy, icon: "checkmark.circle")
        StatCard(title: "Medium", value: "85", color: Theme.Colors.medium, icon: "flame")
        StatCard(title: "Hard", value: "30", color: Theme.Colors.hard, icon: "bolt.fill")
    }
    .padding()
    .background(Theme.Colors.background)
}
