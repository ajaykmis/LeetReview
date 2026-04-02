import SwiftUI

struct DailyChallengeCard: View {
    let challenge: DailyChallenge

    private var difficultyColor: Color {
        switch challenge.question.difficulty.lowercased() {
        case "easy": Theme.Colors.easy
        case "medium": Theme.Colors.medium
        case "hard": Theme.Colors.hard
        default: Theme.Colors.textSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.accent)

                Text("Daily Challenge")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Colors.accent)

                Spacer()

                Text(challenge.date)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Text(challenge.question.title)
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)
                .lineLimit(2)

            HStack {
                DifficultyBadge(difficulty: challenge.question.difficulty)

                Spacer()

                HStack(spacing: Theme.Spacing.xs) {
                    Text("Solve")
                        .font(.subheadline.bold())
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundStyle(Theme.Colors.accent)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.Colors.card)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [difficultyColor.opacity(0.5), difficultyColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

#Preview {
    let challenge = DailyChallenge(
        date: "2026-04-01",
        question: DailyChallengeQuestion(
            titleSlug: "two-sum",
            title: "Two Sum",
            difficulty: "Easy"
        )
    )

    DailyChallengeCard(challenge: challenge)
        .padding()
        .background(Theme.Colors.background)
}
