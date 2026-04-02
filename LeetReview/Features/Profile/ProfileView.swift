import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.profile == nil {
                    ProgressView()
                        .tint(Theme.Colors.accent)
                } else if let errorMessage = viewModel.errorMessage, viewModel.profile == nil {
                    errorView(message: errorMessage)
                } else {
                    profileContent
                }
            }
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                if let username = authManager.username {
                    await viewModel.loadProfile(username: username)
                }
            }
            .refreshable {
                if let username = authManager.username {
                    await viewModel.loadProfile(username: username)
                }
            }
        }
    }

    // MARK: - Profile Content

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                headerSection
                statsCards
                difficultyBreakdown
                rankingSection
                recentSubmissionsSection
            }
            .padding(Theme.Spacing.lg)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.accent)

            Text(authManager.username ?? "User")
                .font(.title2.bold())
                .foregroundStyle(Theme.Colors.text)

            Text("\(viewModel.totalSolved) problems solved")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatCard(
                title: "Easy",
                value: "\(viewModel.easySolved)",
                color: Theme.Colors.easy,
                icon: "checkmark.circle"
            )

            StatCard(
                title: "Medium",
                value: "\(viewModel.mediumSolved)",
                color: Theme.Colors.medium,
                icon: "flame"
            )

            StatCard(
                title: "Hard",
                value: "\(viewModel.hardSolved)",
                color: Theme.Colors.hard,
                icon: "bolt.fill"
            )
        }
    }

    // MARK: - Difficulty Breakdown with Progress Bars

    private var difficultyBreakdown: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Difficulty Breakdown")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            DifficultyProgressRow(
                label: "Easy",
                solved: viewModel.easySolved,
                color: Theme.Colors.easy
            )

            DifficultyProgressRow(
                label: "Medium",
                solved: viewModel.mediumSolved,
                color: Theme.Colors.medium
            )

            DifficultyProgressRow(
                label: "Hard",
                solved: viewModel.hardSolved,
                color: Theme.Colors.hard
            )
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Ranking

    private var rankingSection: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatCard(
                title: "Ranking",
                value: viewModel.ranking > 0 ? "#\(formatNumber(viewModel.ranking))" : "--",
                color: Theme.Colors.accent,
                icon: "trophy"
            )

            StatCard(
                title: "Reputation",
                value: "\(viewModel.reputation)",
                color: Theme.Colors.accent,
                icon: "star.fill"
            )
        }
    }

    // MARK: - Recent Submissions

    private var recentSubmissionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Recent Accepted")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.text)

                Spacer()

                Text("\(viewModel.recentSubmissions.count)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if viewModel.recentSubmissions.isEmpty {
                Text("No recent submissions")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.Spacing.xl)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.recentSubmissions) { submission in
                        NavigationLink(value: submission.titleSlug) {
                            RecentSubmissionRow(submission: submission)
                        }
                        .buttonStyle(.plain)

                        if submission.id != viewModel.recentSubmissions.last?.id {
                            Divider()
                                .background(Theme.Colors.textSecondary.opacity(0.2))
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .navigationDestination(for: String.self) { slug in
            // Navigate to problem detail when available; placeholder for now
            ProblemDetailPlaceholder(titleSlug: slug)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.hard)

            Text("Failed to load profile")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    if let username = authManager.username {
                        await viewModel.loadProfile(username: username)
                    }
                }
            } label: {
                Text("Retry")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Colors.background)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
        }
        .padding(Theme.Spacing.xl)
    }

    // MARK: - Helpers

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Difficulty Progress Row

private struct DifficultyProgressRow: View {
    let label: String
    let solved: Int
    let color: Color

    // Approximate total counts on LeetCode (used for progress bar scale)
    private var estimatedTotal: Int {
        switch label.lowercased() {
        case "easy": return 800
        case "medium": return 1700
        case "hard": return 800
        default: return 1000
        }
    }

    private var progress: Double {
        guard estimatedTotal > 0 else { return 0 }
        return min(Double(solved) / Double(estimatedTotal), 1.0)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(color)

                Spacer()

                Text("\(solved)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(Theme.Colors.text)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Recent Submission Row

private struct RecentSubmissionRow: View {
    let submission: RecentSubmission

    private var relativeTime: String {
        guard let date = Date.fromTimestamp(submission.timestamp) else {
            return ""
        }
        return date.relativeString()
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.Colors.easy)
                .font(.body)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(submission.title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.sm) {
                    Text(submission.lang)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.accent)

                    Text(relativeTime)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.md)
    }
}

// MARK: - Problem Detail Placeholder (until Stage 3 is wired)

private struct ProblemDetailPlaceholder: View {
    let titleSlug: String

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            Text(titleSlug)
                .foregroundStyle(Theme.Colors.text)
        }
        .navigationTitle(titleSlug)
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environment(AuthManager())
}
