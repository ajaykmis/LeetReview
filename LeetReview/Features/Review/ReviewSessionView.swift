import SwiftUI
import SwiftData

struct ReviewSessionView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ReviewViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if viewModel.sessionComplete && viewModel.reviewedCount > 0 {
                    sessionCompleteView
                } else if !viewModel.hasItems && viewModel.reviewedCount == 0 {
                    emptyStateView
                } else {
                    reviewContent
                }
            }
            .navigationTitle("Review")
            .toolbarBackground(Theme.Colors.background, for: .navigationBar)
            .toolbarColorScheme(themeManager.toolbarColorScheme, for: .navigationBar)
            .toolbar {
                if viewModel.hasItems {
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
    }

    // MARK: - Review Content

    private var reviewContent: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Progress bar
            ProgressView(value: viewModel.progressFraction)
                .tint(Theme.Colors.accent)
                .padding(.horizontal, Theme.Spacing.lg)

            // Card
            if let item = viewModel.currentItem {
                ReviewCardView(
                    item: item,
                    isFlipped: viewModel.isFlipped,
                    isLoadingCode: viewModel.isLoadingCode,
                    code: viewModel.currentCode,
                    language: viewModel.currentLang,
                    errorMessage: viewModel.errorMessage,
                    onShowSolution: {
                        Task {
                            await viewModel.showSolution()
                        }
                    }
                )
                .padding(.horizontal, Theme.Spacing.lg)
            }

            // Rating buttons (shown when flipped)
            if viewModel.isFlipped {
                ratingButtons
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isFlipped)
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("How well did you recall?")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ReviewQuality.allCases, id: \.rawValue) { quality in
                    ratingButton(quality: quality)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(.bottom, Theme.Spacing.md)
    }

    private func ratingButton(quality: ReviewQuality) -> some View {
        Button {
            viewModel.rate(quality: quality)
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Text(quality.label)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .foregroundStyle(ratingColor(quality))
            .background(ratingColor(quality).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func ratingColor(_ quality: ReviewQuality) -> Color {
        switch quality {
        case .again: Theme.Colors.hard
        case .hard: Theme.Colors.medium
        case .good: Theme.Colors.accent
        case .easy: Theme.Colors.easy
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.easy)

            Text("No Reviews Due")
                .font(.title2.bold())
                .foregroundStyle(Theme.Colors.text)

            Text("You're all caught up! Add solved problems\nto your review queue from the Problems tab.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            // Stats
            HStack(spacing: Theme.Spacing.lg) {
                StatCard(
                    title: "Total",
                    value: "\(viewModel.totalInQueue)",
                    color: Theme.Colors.accent,
                    icon: "tray.full"
                )
                StatCard(
                    title: "Due",
                    value: "\(viewModel.totalDueCount)",
                    color: Theme.Colors.easy,
                    icon: "clock"
                )
            }
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
                viewModel.resetSession()
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "arrow.clockwise")
                    Text("Check for More")
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
}

#Preview {
    ReviewSessionView()
        .modelContainer(for: ReviewItem.self, inMemory: true)
}
