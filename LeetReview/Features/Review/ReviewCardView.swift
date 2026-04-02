import SwiftUI

struct ReviewCardView: View {
    let item: ReviewItem
    let isFlipped: Bool
    let isLoadingCode: Bool
    let code: String?
    let language: String?
    let errorMessage: String?
    let onShowSolution: () -> Void

    var body: some View {
        ZStack {
            if isFlipped {
                backFace
                    .rotation3DEffect(.degrees(0), axis: (x: 0, y: 1, z: 0))
            } else {
                frontFace
                    .rotation3DEffect(.degrees(0), axis: (x: 0, y: 1, z: 0))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isFlipped)
    }

    // MARK: - Front Face

    private var frontFace: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // Problem title
            Text(item.title)
                .font(.title2.bold())
                .foregroundStyle(Theme.Colors.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.lg)

            // Difficulty badge
            DifficultyBadge(difficulty: item.difficulty)

            // Review stats
            HStack(spacing: Theme.Spacing.lg) {
                reviewStat(label: "Interval", value: intervalString(item.interval))
                reviewStat(label: "Ease", value: String(format: "%.1f", item.easeFactor))
                reviewStat(label: "Reps", value: "\(item.repetitions)")
            }
            .padding(.top, Theme.Spacing.md)

            Spacer()

            // Show Solution button
            Button(action: onShowSolution) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "eye.fill")
                    Text("Show Solution")
                }
                .font(.headline)
                .foregroundStyle(Theme.Colors.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.Colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(difficultyBorderColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Back Face

    private var backFace: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)

                Spacer()

                DifficultyBadge(difficulty: item.difficulty)
            }
            .padding(Theme.Spacing.lg)

            Divider()
                .background(Theme.Colors.textSecondary.opacity(0.3))

            // Code area
            if isLoadingCode {
                Spacer()
                ProgressView()
                    .tint(Theme.Colors.accent)
                Text("Loading your solution...")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, Theme.Spacing.sm)
                Spacer()
            } else if let errorMessage {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(Theme.Colors.medium)
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
                Spacer()
            } else if let code {
                // Language label
                if let language {
                    HStack {
                        Text(language)
                            .font(.caption.bold())
                            .foregroundStyle(Theme.Colors.accent)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(Theme.Colors.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Spacer()

                        Button {
                            UIPasteboard.general.string = code
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                }

                // Scrollable code
                ScrollView {
                    Text(code)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.Colors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.md)
                }
                .background(Color(hex: 0x181825))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            } else {
                Spacer()
                Text("No code available")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.Colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(difficultyBorderColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var difficultyBorderColor: Color {
        switch item.difficulty.lowercased() {
        case "easy": Theme.Colors.easy
        case "medium": Theme.Colors.medium
        case "hard": Theme.Colors.hard
        default: Theme.Colors.accent
        }
    }

    private func reviewStat(label: String, value: String) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(Theme.Colors.text)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func intervalString(_ interval: Double) -> String {
        if interval < 1 {
            return "<1d"
        } else if interval < 30 {
            return "\(Int(interval.rounded()))d"
        } else if interval < 365 {
            let months = interval / 30.0
            return String(format: "%.1fmo", months)
        } else {
            let years = interval / 365.0
            return String(format: "%.1fy", years)
        }
    }
}

#Preview("Front") {
    let item = ReviewItem(
        titleSlug: "two-sum",
        title: "Two Sum",
        difficulty: "Easy",
        interval: 6.0,
        easeFactor: 2.5,
        repetitions: 3
    )

    ReviewCardView(
        item: item,
        isFlipped: false,
        isLoadingCode: false,
        code: nil,
        language: nil,
        errorMessage: nil,
        onShowSolution: {}
    )
    .frame(height: 400)
    .padding()
    .background(Theme.Colors.background)
}

#Preview("Back") {
    let item = ReviewItem(
        titleSlug: "two-sum",
        title: "Two Sum",
        difficulty: "Easy"
    )

    ReviewCardView(
        item: item,
        isFlipped: true,
        isLoadingCode: false,
        code: """
        class Solution:
            def twoSum(self, nums: List[int], target: int) -> List[int]:
                seen = {}
                for i, num in enumerate(nums):
                    complement = target - num
                    if complement in seen:
                        return [seen[complement], i]
                    seen[num] = i
                return []
        """,
        language: "Python3",
        errorMessage: nil,
        onShowSolution: {}
    )
    .frame(height: 400)
    .padding()
    .background(Theme.Colors.background)
}
