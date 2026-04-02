import SwiftUI
import SwiftData

struct ReviewSessionView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ReviewViewModel()
    @State private var isInSessionMode = false
    @State private var showDismissConfirmation: ReviewItem?
    @State private var solutionSheetItem: ReviewItem?
    @State private var solutionCode: String?
    @State private var solutionLang: String?
    @State private var isLoadingSolution = false
    @State private var editorProblem: CodeEditorProblemSnapshot?
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if isInSessionMode {
                    if viewModel.sessionComplete && viewModel.reviewedCount > 0 {
                        sessionCompleteView
                    } else if viewModel.hasItems {
                        sessionContent
                    } else {
                        // Edge case: entered session but items disappeared
                        sessionCompleteView
                    }
                } else if viewModel.allItems.isEmpty {
                    emptyStateView
                } else {
                    queueView
                }
            }
            .navigationTitle("Review")
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbarColorScheme(themeManager.toolbarColorScheme, for: .navigationBar)
            .toolbar {
                if isInSessionMode && viewModel.hasItems {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isInSessionMode = false
                        } label: {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "chevron.left")
                                Text("Queue")
                            }
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.accent)
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Text(viewModel.progressText)
                            .font(.caption.bold())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext)
            viewModel.loadDueItems()
        }
        .sheet(item: $solutionSheetItem) { item in
            solutionSheet(for: item)
        }
        .fullScreenCover(isPresented: $showEditor) {
            if let problem = editorProblem {
                NavigationStack {
                    CodeEditorView(problem: problem)
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
        .alert("Remove from Review?", isPresented: .init(
            get: { showDismissConfirmation != nil },
            set: { if !$0 { showDismissConfirmation = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let item = showDismissConfirmation {
                    viewModel.dismissItem(item)
                }
                showDismissConfirmation = nil
            }
            Button("Cancel", role: .cancel) {
                showDismissConfirmation = nil
            }
        } message: {
            if let item = showDismissConfirmation {
                Text("This will remove \"\(item.title)\" from your review queue permanently.")
            }
        }
    }

    // MARK: - Queue View

    private var queueView: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Header stats
                    queueHeader
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.lg)

                    // Due Now section
                    if !viewModel.dueItems.isEmpty {
                        sectionHeader(title: "Due Now", count: viewModel.dueItems.count, color: Theme.Colors.hard)
                            .padding(.horizontal, Theme.Spacing.lg)

                        ForEach(viewModel.dueItems) { item in
                            reviewPillCard(item: item, isDue: true)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.bottom, Theme.Spacing.sm)
                        }
                    }

                    // Upcoming section
                    if !viewModel.upcomingItems.isEmpty {
                        sectionHeader(title: "Upcoming", count: viewModel.upcomingItems.count, color: Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.top, viewModel.dueItems.isEmpty ? 0 : Theme.Spacing.lg)

                        ForEach(viewModel.upcomingItems) { item in
                            reviewPillCard(item: item, isDue: false)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .padding(.bottom, Theme.Spacing.sm)
                        }
                    }
                }
                .padding(.bottom, viewModel.dueItems.isEmpty ? Theme.Spacing.lg : 80)
            }

            // Start Review Session button
            if !viewModel.dueItems.isEmpty {
                startSessionButton
            }
        }
    }

    private var queueHeader: some View {
        HStack(spacing: Theme.Spacing.lg) {
            StatCard(
                title: "Due",
                value: "\(viewModel.dueItems.count)",
                color: Theme.Colors.hard,
                icon: "clock.badge.exclamationmark"
            )
            StatCard(
                title: "Total",
                value: "\(viewModel.allItems.count)",
                color: Theme.Colors.accent,
                icon: "tray.full"
            )
        }
    }

    private func sectionHeader(title: String, count: Int, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(color)

            Text("\(count)")
                .font(.caption.bold())
                .foregroundStyle(color.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.15))
                .clipShape(Capsule())

            Spacer()
        }
        .padding(.bottom, Theme.Spacing.sm)
    }

    private func reviewPillCard(item: ReviewItem, isDue: Bool) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Top row: title + difficulty
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(item.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.Colors.text)
                        .lineLimit(1)

                    HStack(spacing: Theme.Spacing.md) {
                        Text(viewModel.relativeDueDate(for: item))
                            .font(.caption)
                            .foregroundStyle(isDue ? Theme.Colors.hard : Theme.Colors.textSecondary)

                        Text("\(item.repetitions) reps")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        Text("EF \(String(format: "%.1f", item.easeFactor))")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                Spacer()

                DifficultyBadge(difficulty: item.difficulty)
            }

            // Action buttons
            HStack(spacing: Theme.Spacing.sm) {
                // Practice button
                Button {
                    openPractice(for: item)
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.caption)
                        Text("Practice")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Show Solution button
                Button {
                    solutionSheetItem = item
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "eye")
                            .font(.caption)
                        Text("Solution")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(Theme.Colors.easy)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.easy.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                // Dismiss button
                Button {
                    showDismissConfirmation = item
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Colors.textSecondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.Colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(
                    isDue ? difficultyBorderColor(for: item).opacity(0.2) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    private var startSessionButton: some View {
        Button {
            viewModel.loadDueItems()
            isInSessionMode = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "brain.head.profile")
                Text("Start Review Session")
            }
            .font(.headline)
            .foregroundStyle(Theme.Colors.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            Theme.Colors.background
                .shadow(.drop(color: Theme.Colors.background.opacity(0.8), radius: 8, y: -4))
        )
    }

    // MARK: - Session View

    private var sessionContent: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Progress bar
            ProgressView(value: viewModel.progressFraction)
                .tint(Theme.Colors.accent)
                .padding(.horizontal, Theme.Spacing.lg)

            // Card
            if let item = viewModel.currentItem {
                let previews = currentIntervalPreviews(for: item)

                ReviewCardView(
                    item: item,
                    isFlipped: viewModel.isFlipped,
                    isLoadingCode: viewModel.isLoadingCode,
                    code: viewModel.currentCode,
                    language: viewModel.currentLang,
                    errorMessage: viewModel.errorMessage,
                    intervalPreviews: previews,
                    onShowSolution: {
                        Task {
                            await viewModel.showSolution()
                        }
                    }
                )
                .padding(.horizontal, Theme.Spacing.lg)
            }

            // Rating buttons (shown when flipped)
            if viewModel.isFlipped, let item = viewModel.currentItem {
                SessionRatingButtons(
                    item: item,
                    intervalPreviews: currentIntervalPreviews(for: item),
                    onRate: { quality in
                        viewModel.rate(quality: quality)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isFlipped)
    }

    private func currentIntervalPreviews(for item: ReviewItem) -> [ReviewQuality: String] {
        var previews: [ReviewQuality: String] = [:]
        for quality in ReviewQuality.allCases {
            previews[quality] = viewModel.previewInterval(for: item, quality: quality)
        }
        return previews
    }

    // MARK: - Solution Sheet

    private func solutionSheet(for item: ReviewItem) -> some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundStyle(Theme.Colors.text)
                            DifficultyBadge(difficulty: item.difficulty)
                        }
                        Spacer()
                    }
                    .padding(Theme.Spacing.lg)

                    Divider()
                        .background(Theme.Colors.textSecondary.opacity(0.3))

                    if isLoadingSolution {
                        Spacer()
                        ProgressView()
                            .tint(Theme.Colors.accent)
                        Text("Loading solution...")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.top, Theme.Spacing.sm)
                        Spacer()
                    } else if let code = solutionCode {
                        if let lang = solutionLang {
                            HStack {
                                Text(lang)
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
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.top, Theme.Spacing.sm)
                        }

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
                        Text("No solution available")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Solution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        solutionSheetItem = nil
                    }
                    .foregroundStyle(Theme.Colors.accent)
                }
            }
        }
        .onAppear {
            loadSolution(for: item)
        }
        .onDisappear {
            solutionCode = nil
            solutionLang = nil
        }
    }

    private func loadSolution(for item: ReviewItem) {
        isLoadingSolution = true
        solutionCode = nil
        solutionLang = nil

        Task {
            let result = await viewModel.loadSolutionCode(for: item)
            solutionCode = result.code
            solutionLang = result.lang
            isLoadingSolution = false
        }
    }

    // MARK: - Practice (Code Editor)

    private func openPractice(for item: ReviewItem) {
        Task {
            do {
                let detail = try await LeetCodeAPI.shared.fetchProblemDetail(titleSlug: item.titleSlug)
                if let snapshot = CodeEditorProblemSnapshot(detail: detail, fallbackTitle: item.title) {
                    editorProblem = snapshot
                    showEditor = true
                } else {
                    // Create a minimal snapshot as fallback
                    editorProblem = CodeEditorProblemSnapshot(
                        questionId: "0",
                        title: item.title,
                        titleSlug: item.titleSlug,
                        difficulty: item.difficulty,
                        summary: "Practice this problem.",
                        starterCodes: [
                            CodeEditorStarterCode(
                                languageName: "Swift",
                                languageSlug: "swift",
                                code: "// Start coding here\n"
                            )
                        ],
                        initialTestCases: [
                            CodeEditorTestCase(label: "Case 1", input: "", expectedOutput: "")
                        ]
                    )
                    showEditor = true
                }
            } catch {
                // Fallback: create minimal snapshot
                editorProblem = CodeEditorProblemSnapshot(
                    questionId: "0",
                    title: item.title,
                    titleSlug: item.titleSlug,
                    difficulty: item.difficulty,
                    summary: "Practice this problem.",
                    starterCodes: [
                        CodeEditorStarterCode(
                            languageName: "Swift",
                            languageSlug: "swift",
                            code: "// Start coding here\n"
                        )
                    ],
                    initialTestCases: [
                        CodeEditorTestCase(label: "Case 1", input: "", expectedOutput: "")
                    ]
                )
                showEditor = true
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.easy)

            Text("No Reviews Yet")
                .font(.title2.bold())
                .foregroundStyle(Theme.Colors.text)

            Text("Add solved problems to your review queue\nfrom the Problems tab.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            AdBannerView()
                .padding(.horizontal, Theme.Spacing.xl)

            Spacer()

            Button {
                viewModel.loadDueItems()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.headline)
                .foregroundStyle(Theme.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    // MARK: - Session Complete

    private var sessionCompleteView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "party.popper.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.accent)

            Text("Session Complete!")
                .font(.title2.bold())
                .foregroundStyle(Theme.Colors.text)

            Text("You reviewed \(viewModel.reviewedCount) problem\(viewModel.reviewedCount == 1 ? "" : "s").\nGreat work!")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                isInSessionMode = false
                viewModel.resetSession()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "arrow.clockwise")
                    Text("Back to Queue")
                }
                .font(.headline)
                .foregroundStyle(Theme.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    // MARK: - Helpers

    private func difficultyBorderColor(for item: ReviewItem) -> Color {
        switch item.difficulty.lowercased() {
        case "easy": Theme.Colors.easy
        case "medium": Theme.Colors.medium
        case "hard": Theme.Colors.hard
        default: Theme.Colors.accent
        }
    }
}

#Preview {
    ReviewSessionView()
        .modelContainer(for: ReviewItem.self, inMemory: true)
}
