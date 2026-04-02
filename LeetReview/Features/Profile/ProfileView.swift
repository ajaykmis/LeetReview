import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ThemeManager.self) private var themeManager
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
            .toolbarColorScheme(themeManager.toolbarColorScheme, for: .navigationBar)
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

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                headerSection
                if viewModel.contestRanking != nil {
                    contestSection
                }
                progressSnapshot
                difficultyBreakdown
                activityHeatmap
                languageBreakdown
                recentSubmissionsSection
            }
            .padding(Theme.Spacing.lg)
        }
    }

    @ViewBuilder
    private var contestSection: some View {
        if let contest = viewModel.contestRanking {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Contest")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.text)

                HStack(spacing: Theme.Spacing.md) {
                    if let rating = contest.rating {
                        insightPill(title: "Rating", value: String(format: "%.0f", rating))
                    }
                    if let globalRanking = contest.globalRanking, globalRanking > 0 {
                        insightPill(title: "Global Rank", value: "#\(formatNumber(globalRanking))")
                    }
                    if let attended = contest.attendedContestsCount {
                        insightPill(title: "Attended", value: "\(attended)")
                    }
                }

                if let topPercent = contest.topPercentage, topPercent > 0 {
                    Text("Top \(String(format: "%.1f", topPercent))% of all contestants")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                if let avatarURL = viewModel.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 58))
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(Theme.Colors.accent)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(authManager.username ?? "User")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.Colors.text)

                    if let realName = viewModel.realName {
                        Text(realName)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Text("\(viewModel.totalSolved) problems solved")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Text(viewModel.momentumHeadline)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.accent)
                }

                Spacer()
            }

            // Profile details
            if viewModel.company != nil || viewModel.school != nil {
                HStack(spacing: Theme.Spacing.lg) {
                    if let company = viewModel.company {
                        Label(company, systemImage: "building.2")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    if let school = viewModel.school {
                        Label(school, systemImage: "graduationcap")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }

            HStack(spacing: Theme.Spacing.md) {
                insightPill(title: "Rank", value: viewModel.ranking > 0 ? "#\(formatNumber(viewModel.ranking))" : "--")
                insightPill(title: "Reputation", value: "\(viewModel.reputation)")
                insightPill(title: "Active Days", value: "\(viewModel.activeDaysCount)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private var progressSnapshot: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Progress Snapshot")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

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

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Weekly consistency")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.text)
                    Spacer()
                    Text("\(Int(viewModel.weeklyGoalProgress * 100))%")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(Theme.Colors.accent)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.Colors.background.opacity(0.7))
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.Colors.accent)
                            .frame(width: geometry.size.width * viewModel.weeklyGoalProgress, height: 10)
                    }
                }
                .frame(height: 10)

                Text("Suggested focus: \(viewModel.nextFocus)")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private var difficultyBreakdown: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Difficulty Breakdown")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            DifficultyProgressRow(label: "Easy", solved: viewModel.easySolved, color: Theme.Colors.easy)
            DifficultyProgressRow(label: "Medium", solved: viewModel.mediumSolved, color: Theme.Colors.medium)
            DifficultyProgressRow(label: "Hard", solved: viewModel.hardSolved, color: Theme.Colors.hard)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private var activityHeatmap: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Activity Heatmap")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.text)
                Spacer()
                Text("Last 8 weeks")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(viewModel.heatmapDays) { day in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(heatmapColor(for: day.intensity))
                        .frame(height: 22)
                        .overlay(alignment: .bottomTrailing) {
                            if day.count > 0 {
                                Text("\(min(day.count, 9))")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.Colors.background.opacity(0.9))
                                    .padding(3)
                            }
                        }
                }
            }

            Text("Accepted-submission activity is approximated from the recent submissions payload until a full calendar API is wired.")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private var languageBreakdown: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Languages")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            if viewModel.languageBreakdown.isEmpty {
                Text("No recent language data yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(viewModel.languageBreakdown) { item in
                    HStack {
                        Text(item.language)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.text)

                        Spacer()

                        Text("\(item.count)")
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

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
                        NavigationLink {
                            ProblemDetailView(
                                titleSlug: submission.titleSlug,
                                title: submission.title
                            )
                        } label: {
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
    }

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

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func insightPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(Theme.Colors.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func heatmapColor(for intensity: Int) -> Color {
        switch intensity {
        case 0: Theme.Colors.background.opacity(0.8)
        case 1: Theme.Colors.easy.opacity(0.35)
        case 2: Theme.Colors.easy.opacity(0.55)
        case 3: Theme.Colors.accent.opacity(0.7)
        default: Theme.Colors.accent
        }
    }
}

private struct DifficultyProgressRow: View {
    let label: String
    let solved: Int
    let color: Color

    private var estimatedTotal: Int {
        switch label.lowercased() {
        case "easy":
            return 800
        case "medium":
            return 1700
        case "hard":
            return 800
        default:
            return 1000
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

#Preview {
    ProfileView()
        .environment(AuthManager())
}
