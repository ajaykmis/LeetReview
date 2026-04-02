import SwiftUI
@preconcurrency import WebKit

struct ProblemDetailView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(OfflineManager.self) private var offlineManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ProblemDetailViewModel
    @State private var problemHTMLHeight: CGFloat = 320
    @State private var editorialHTMLHeight: CGFloat = 320

    init(titleSlug: String, title: String) {
        _viewModel = State(wrappedValue: ProblemDetailViewModel(
            titleSlug: titleSlug,
            title: title
        ))
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            if viewModel.isLoadingDetail && viewModel.detail == nil {
                ProgressView()
                    .tint(Theme.Colors.accent)
            } else if let error = viewModel.detailError, viewModel.detail == nil {
                errorView(message: error)
            } else if let detail = viewModel.detail {
                detailContent(detail)
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbarColorScheme(themeManager.toolbarColorScheme, for: .navigationBar)
        .task {
            viewModel.configureOffline(offlineManager: offlineManager)
            viewModel.configureReview(modelContext: modelContext)
            await viewModel.loadAll()
        }
    }

    @State private var showEditor = false

    @ViewBuilder
    private func detailContent(_ detail: ProblemDetail) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    headerSection(detail)
                    tagsSection(detail.topicTags)
                    sectionPicker
                    sectionContent(detail)
                    submissionsSection
                    Spacer(minLength: 80) // room for floating pill
                }
                .padding(Theme.Spacing.lg)
            }

            // Floating code editor pill
            if let editorProblem = viewModel.editorProblem {
                Button {
                    showEditor = true
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.body.bold())
                        Text("Code")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(Theme.Colors.background)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.accent)
                    .clipShape(Capsule())
                    .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
                .fullScreenCover(isPresented: $showEditor) {
                    NavigationStack {
                        CodeEditorView(problem: editorProblem)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button {
                                        showEditor = false
                                    } label: {
                                        Image(systemName: "xmark")
                                            .foregroundStyle(Theme.Colors.text)
                                    }
                                }
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func headerSection(_ detail: ProblemDetail) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(viewModel.title)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.Colors.text)

                    DifficultyBadge(difficulty: detail.difficulty)
                }

                Spacer()

                statsRow(detail)
            }

            Text(viewModel.insightSummary)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)

            HStack(spacing: Theme.Spacing.md) {
                metricPill(
                    title: "Accepted",
                    value: viewModel.totalAccepted ?? "--",
                    color: Theme.Colors.easy
                )
                metricPill(
                    title: "Attempts",
                    value: viewModel.totalSubmissions ?? "--",
                    color: Theme.Colors.medium
                )
            }

            // Add to Review button
            Button {
                viewModel.addToReview()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: viewModel.addedToReview
                        ? "checkmark.circle.fill"
                        : "arrow.counterclockwise.circle")
                    Text(viewModel.addedToReview ? "In Review Queue" : "Add to Review")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(viewModel.addedToReview ? Theme.Colors.easy : Theme.Colors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    viewModel.addedToReview
                        ? Theme.Colors.easy.opacity(0.12)
                        : Theme.Colors.background.opacity(0.7)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.addedToReview)
            .buttonStyle(.plain)

            // Save Offline button
            Button {
                viewModel.toggleSaveOffline()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: viewModel.isSavedOffline
                        ? "checkmark.circle.fill"
                        : "arrow.down.circle")
                    Text(viewModel.isSavedOffline ? "Saved Offline" : "Save Offline")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(viewModel.isSavedOffline ? Theme.Colors.accent : Theme.Colors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    viewModel.isSavedOffline
                        ? Theme.Colors.accent.opacity(0.12)
                        : Theme.Colors.background.opacity(0.7)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    @ViewBuilder
    private func statsRow(_ detail: ProblemDetail) -> some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.sm) {
            if let rate = viewModel.acceptanceRate {
                statItem(icon: "chart.bar.fill", label: rate)
            }

            statItem(
                icon: "hand.thumbsup.fill",
                label: "\(detail.likes)",
                color: Theme.Colors.easy
            )

            statItem(
                icon: "hand.thumbsdown.fill",
                label: "\(detail.dislikes)",
                color: Theme.Colors.hard
            )
        }
    }

    @ViewBuilder
    private func statItem(
        icon: String,
        label: String,
        color: Color = Theme.Colors.textSecondary
    ) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    @ViewBuilder
    private func metricPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func tagsSection(_ tags: [TopicTag]) -> some View {
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Topics")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Colors.text)

                FlowLayout(spacing: Theme.Spacing.sm) {
                    ForEach(tags, id: \.name) { tag in
                        Text(tag.name)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.accent)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(Theme.Colors.accent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ProblemDetailViewModel.DetailSection.allCases) { section in
                    Button {
                        viewModel.selectedSection = section
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: section.icon)
                            Text(section.rawValue)
                        }
                        .font(.caption.bold())
                        .foregroundStyle(
                            viewModel.selectedSection == section ? Theme.Colors.background : Theme.Colors.text
                        )
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            viewModel.selectedSection == section
                                ? Theme.Colors.accent
                                : Theme.Colors.card
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionContent(_ detail: ProblemDetail) -> some View {
        switch viewModel.selectedSection {
        case .description:
            if let content = detail.content, !content.isEmpty {
                problemStatementSection(content)
            } else {
                placeholderSection(
                    title: "Description unavailable",
                    message: "Problem content was not returned for this question."
                )
            }
        case .hints:
            hintsSection
        case .editorial:
            editorialSection
        case .community:
            communitySection
        case .similar:
            similarSection
        }
    }

    @ViewBuilder
    private func problemStatementSection(_ html: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Description")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Colors.text)

            ProblemHTMLView(
                htmlContent: html,
                colorScheme: themeManager.preferredColorScheme,
                contentHeight: $problemHTMLHeight
            )
                .frame(height: max(problemHTMLHeight, 320))
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    @ViewBuilder
    private var hintsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionTitle("Hints")

            if viewModel.isLoadingHints && viewModel.hints.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().tint(Theme.Colors.accent)
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.lg)
            } else if viewModel.hints.isEmpty {
                Text("No hints available for this problem.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(Array(viewModel.hints.enumerated()), id: \.offset) { index, hint in
                    DisclosureGroup {
                        Text(hint.strippingHTMLTags())
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.top, Theme.Spacing.xs)
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.Colors.background)
                                .frame(width: 22, height: 22)
                                .background(Theme.Colors.medium)
                                .clipShape(Circle())
                            Text("Hint \(index + 1)")
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.Colors.text)
                        }
                    }
                    .tint(Theme.Colors.accent)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    @ViewBuilder
    private var editorialSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionTitle("Editorial")

            if viewModel.isLoadingEditorial {
                HStack {
                    Spacer()
                    ProgressView().tint(Theme.Colors.accent)
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.lg)
            } else if let solution = viewModel.editorialSolution {
                if solution.paidOnly == true && solution.canSeeDetail != true {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.medium)
                        Text("This editorial requires a LeetCode Premium subscription.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, Theme.Spacing.md)
                } else if let content = solution.content, !content.isEmpty {
                    ProblemHTMLView(
                        htmlContent: content,
                        colorScheme: themeManager.preferredColorScheme,
                        contentHeight: $editorialHTMLHeight
                    )
                    .frame(height: max(editorialHTMLHeight, 200))
                } else {
                    Text("Editorial content is empty.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            } else if let error = viewModel.editorialError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.hard)
            } else {
                Text("No editorial available for this problem.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            NavigationLink {
                AuthenticatedBrowserPage(
                    title: "Editorial",
                    url: URL(string: "https://leetcode.com/problems/\(viewModel.titleSlug)/editorial/")!
                )
            } label: {
                externalActionRow(
                    title: "Open Editorial in Browser",
                    subtitle: "Uses your LeetCode session when available.",
                    tint: Theme.Colors.easy
                )
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    @ViewBuilder
    private var communitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                sectionTitle("Community")
                Spacer()
                if viewModel.communityTotal > 0 {
                    Text("\(viewModel.communityTotal) solutions")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            if viewModel.isLoadingCommunity && viewModel.communitySolutions.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().tint(Theme.Colors.accent)
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.lg)
            } else if let error = viewModel.communityError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.hard)
            } else if viewModel.communitySolutions.isEmpty {
                Text("No community solutions found.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(viewModel.communitySolutions) { solution in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(solution.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.Colors.text)
                            .lineLimit(2)

                        HStack(spacing: Theme.Spacing.md) {
                            if let votes = solution.post.voteCount {
                                Label("\(votes)", systemImage: "arrow.up")
                                    .font(.caption)
                                    .foregroundStyle(votes > 0 ? Theme.Colors.easy : Theme.Colors.textSecondary)
                            }

                            if let views = solution.viewCount {
                                Label(formatCount(views), systemImage: "eye")
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }

                            if let author = solution.post.author {
                                Text(author.username)
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.accent)
                            }

                            Spacer()
                        }

                        if !solution.solutionTags.isEmpty {
                            HStack(spacing: Theme.Spacing.xs) {
                                ForEach(solution.solutionTags.prefix(3), id: \.name) { tag in
                                    Text(tag.name)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.Colors.accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.Colors.accent.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.background.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            NavigationLink {
                AuthenticatedBrowserPage(
                    title: "Community",
                    url: URL(string: "https://leetcode.com/problems/\(viewModel.titleSlug)/solutions/")!
                )
            } label: {
                externalActionRow(
                    title: "Open Community Solutions",
                    subtitle: "Jump to discussion and solution posts.",
                    tint: Theme.Colors.medium
                )
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    @ViewBuilder
    private var similarSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionTitle("Similar Questions")

            if viewModel.isLoadingSimilar && viewModel.similarQuestions.isEmpty {
                HStack {
                    Spacer()
                    ProgressView().tint(Theme.Colors.accent)
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.lg)
            } else if let error = viewModel.similarError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.hard)
            } else if viewModel.similarQuestions.isEmpty {
                Text("No similar questions found.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(viewModel.similarQuestions) { question in
                    NavigationLink {
                        ProblemDetailView(
                            titleSlug: question.titleSlug,
                            title: question.title
                        )
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(question.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Theme.Colors.text)
                                    .lineLimit(1)
                            }
                            Spacer()
                            DifficultyBadge(difficulty: question.difficulty)
                            if question.isPaidOnly == true {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.medium)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.background.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Theme.Colors.text)
    }

    private func placeholderSection(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private func placeholderFootnote(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.top, Theme.Spacing.xs)
    }

    private func externalActionRow(title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Colors.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right.square.fill")
                .foregroundStyle(tint)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    @ViewBuilder
    private var submissionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("My Submissions")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Colors.text)

                Spacer()

                if !viewModel.submissions.isEmpty {
                    Text("\(viewModel.submissions.count)")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.background)
                        .clipShape(Capsule())
                }
            }

            if viewModel.isLoadingSubmissions && viewModel.submissions.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Theme.Colors.accent)
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.lg)
            } else if let error = viewModel.submissionsError, viewModel.submissions.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.hard)
                    .padding(.vertical, Theme.Spacing.sm)
            } else if viewModel.submissions.isEmpty {
                if authManager.isReadOnly || !authManager.hasLeetCodeSession {
                    Text("Sign in with your LeetCode session to view private submission history.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.vertical, Theme.Spacing.sm)
                } else {
                    Text("No submissions yet")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.vertical, Theme.Spacing.sm)
                }
            } else {
                ForEach(viewModel.submissions.prefix(5)) { submission in
                    NavigationLink {
                        CodeViewerView(submissionId: submission.id, language: submission.lang)
                    } label: {
                        SubmissionRow(submission: submission)
                    }
                }

                if viewModel.submissions.count > 5 {
                    NavigationLink {
                        SubmissionListView(
                            titleSlug: viewModel.titleSlug,
                            submissions: viewModel.submissions
                        )
                    } label: {
                        HStack {
                            Text("View all \(viewModel.submissions.count) submissions")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.accent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.accent)
                        }
                        .padding(.top, Theme.Spacing.sm)
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.Colors.medium)

            Text("Failed to load problem")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.loadAll() }
            } label: {
                Text("Retry")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Colors.background)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(Theme.Spacing.xl)
    }
}

struct SubmissionRow: View {
    let submission: Submission

    private var isAccepted: Bool {
        submission.statusDisplay == "Accepted"
    }

    private var statusColor: Color {
        isAccepted ? Theme.Colors.easy : Theme.Colors.hard
    }

    private var formattedDate: String {
        guard let date = Date.fromTimestamp(submission.timestamp) else {
            return "Unknown"
        }
        return date.relativeString()
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: isAccepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(statusColor)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(submission.statusDisplay)
                    .font(.subheadline)
                    .foregroundStyle(statusColor)

                HStack(spacing: Theme.Spacing.sm) {
                    Text(submission.lang)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.accent)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

struct ProblemHTMLView: UIViewRepresentable {
    let htmlContent: String
    let colorScheme: ColorScheme
    @Binding var contentHeight: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        loadHTML(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.contentHeight = $contentHeight
        loadHTML(in: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight)
    }

    private func loadHTML(in webView: WKWebView) {
        let styledHTML = makeStyledHTML()
        guard webView.url == nil || webView.isLoading || webView.tag != styledHTML.hashValue else {
            return
        }
        webView.tag = styledHTML.hashValue
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }

    private func makeStyledHTML() -> String {
        let palette = HTMLPalette(colorScheme: colorScheme)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <meta name="color-scheme" content="light dark">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src https: data:; script-src 'unsafe-inline';">
        <style>
            * { box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                font-size: 15px;
                line-height: 1.6;
                color: \(palette.text);
                background-color: transparent;
                margin: 0;
                padding: 0;
                -webkit-text-size-adjust: none;
            }
            pre, code {
                font-family: 'SF Mono', 'Menlo', 'Courier New', monospace;
                font-size: 13px;
                background-color: \(palette.codeBackground);
                border-radius: 6px;
                color: \(palette.text);
            }
            pre {
                padding: 12px;
                overflow-x: auto;
                -webkit-overflow-scrolling: touch;
            }
            code {
                padding: 2px 6px;
            }
            pre code {
                padding: 0;
                background: none;
            }
            strong, b { color: \(palette.text); }
            em, i { color: \(palette.secondaryText); }
            a { color: \(palette.link); text-decoration: none; }
            img { max-width: 100%; height: auto; border-radius: 8px; }
            ul, ol { padding-left: 20px; }
            li { margin-bottom: 4px; }
            p { margin: 8px 0; }
            table {
                border-collapse: collapse;
                width: 100%;
                margin: 8px 0;
            }
            th, td {
                border: 1px solid \(palette.border);
                padding: 6px 10px;
                text-align: left;
            }
            th {
                background-color: \(palette.codeBackground);
                color: \(palette.link);
            }
            sup { font-size: 0.75em; }
            sub { font-size: 0.75em; }
        </style>
        </head>
        <body>\(htmlContent)</body>
        </html>
        """
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var contentHeight: Binding<CGFloat>

        init(contentHeight: Binding<CGFloat>) {
            self.contentHeight = contentHeight
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               url.scheme == "https" {
                Task { @MainActor in
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
            } else if navigationAction.navigationType == .linkActivated {
                // Block non-https links (tel:, sms:, javascript:, etc.)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(
                "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);"
            ) { [weak self] result, _ in
                guard let self else { return }

                let measuredHeight: CGFloat?
                if let height = result as? CGFloat {
                    measuredHeight = height
                } else if let height = result as? Double {
                    measuredHeight = height
                } else if let height = result as? Int {
                    measuredHeight = CGFloat(height)
                } else {
                    measuredHeight = nil
                }

                guard let measuredHeight, measuredHeight > 0 else { return }
                Task { @MainActor in
                    self.contentHeight.wrappedValue = measuredHeight
                }
            }
        }
    }
}

extension String {
    func strippingHTMLTags() -> String {
        replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct HTMLPalette {
    let text: String
    let secondaryText: String
    let link: String
    let codeBackground: String
    let border: String

    init(colorScheme: ColorScheme) {
        switch colorScheme {
        case .light:
            text = "#1F2937"
            secondaryText = "#64748B"
            link = "#2563EB"
            codeBackground = "#E2E8F0"
            border = "#CBD5E1"
        case .dark:
            text = "#CDD6F4"
            secondaryText = "#A6ADC8"
            link = "#89B4FA"
            codeBackground = "#1E1E2E"
            border = "#45475A"
        @unknown default:
            text = "#1F2937"
            secondaryText = "#64748B"
            link = "#2563EB"
            codeBackground = "#E2E8F0"
            border = "#CBD5E1"
        }
    }
}
