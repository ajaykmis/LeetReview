import SwiftUI

struct DashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        if viewModel.isLoading && viewModel.dailyChallenge == nil {
                            loadingView
                        } else {
                            dailyChallengeSection
                            quickStatsSection
                            upcomingContestsSection
                            recentActivitySection
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
                .refreshable {
                    await viewModel.loadDashboard(username: authManager.username)
                }
            }
            .navigationTitle("Dashboard")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                if viewModel.dailyChallenge == nil {
                    await viewModel.loadDashboard(username: authManager.username)
                }
            }
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
                .frame(height: 80)
            ProgressView()
                .tint(Theme.Colors.accent)
                .scaleEffect(1.2)
            Text("Loading dashboard...")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
        }
    }

    // MARK: - Daily Challenge

    @ViewBuilder
    private var dailyChallengeSection: some View {
        if let challenge = viewModel.dailyChallenge {
            NavigationLink(value: challenge.question.titleSlug) {
                DailyChallengeCard(challenge: challenge)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Quick Stats

    @ViewBuilder
    private var quickStatsSection: some View {
        if viewModel.userProfile != nil {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                sectionHeader(title: "Your Progress", icon: "chart.bar.fill")

                HStack(spacing: Theme.Spacing.md) {
                    StatCard(
                        title: "Easy",
                        value: "\(viewModel.easySolved)",
                        color: Theme.Colors.easy
                    )
                    StatCard(
                        title: "Medium",
                        value: "\(viewModel.mediumSolved)",
                        color: Theme.Colors.medium
                    )
                    StatCard(
                        title: "Hard",
                        value: "\(viewModel.hardSolved)",
                        color: Theme.Colors.hard
                    )
                }

                // Total solved bar
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.accent)
                    Text("\(viewModel.totalSolved) problems solved")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.Colors.text)

                    Spacer()

                    if let ranking = viewModel.userProfile?.profile.ranking, ranking > 0 {
                        Text("Rank #\(ranking)")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
        }
    }

    // MARK: - Upcoming Contests

    @ViewBuilder
    private var upcomingContestsSection: some View {
        if !viewModel.upcomingContests.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                sectionHeader(title: "Upcoming Contests", icon: "trophy.fill")

                ForEach(viewModel.upcomingContests.prefix(3)) { contest in
                    ContestRow(contest: contest)
                }
            }
        }
    }

    // MARK: - Recent Activity

    @ViewBuilder
    private var recentActivitySection: some View {
        if !viewModel.recentSubmissions.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                sectionHeader(title: "Recent Activity", icon: "clock.fill")

                ForEach(viewModel.recentSubmissions.prefix(5)) { submission in
                    NavigationLink(value: submission.titleSlug) {
                        RecentSubmissionRow(submission: submission)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(Theme.Colors.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)
        }
    }
}

// MARK: - Contest Row

private struct ContestRow: View {
    let contest: Contest

    private var startDate: Date {
        .fromTimestamp(contest.startTime)
    }

    private var countdown: String {
        startDate.countdownString() ?? "Started"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(contest.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)

                Text(startDate.dateTimeString())
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Text(countdown)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(Theme.Colors.accent)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Colors.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

// MARK: - Recent Submission Row

private struct RecentSubmissionRow: View {
    let submission: RecentSubmission

    private var timeAgo: String {
        Date.fromTimestamp(submission.timestamp)?.relativeString() ?? ""
    }

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.Colors.easy)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(submission.title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.sm) {
                    Text(submission.lang)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.accent)

                    Text(timeAgo)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

#Preview {
    DashboardView()
        .environment(AuthManager())
}
