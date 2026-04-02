import SwiftUI

struct ProblemListView: View {
    @State private var viewModel = ProblemListViewModel()
    @State private var showFilters = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                Group {
                    if viewModel.isLoading && viewModel.problems.isEmpty {
                        loadingView
                    } else if let error = viewModel.errorMessage, viewModel.problems.isEmpty {
                        errorView(message: error)
                    } else if viewModel.problems.isEmpty {
                        emptyView
                    } else {
                        problemList
                    }
                }
            }
            .navigationTitle("Problems")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(
                text: $viewModel.searchText,
                prompt: "Search problems..."
            )
            .onSubmit(of: .search) {
                Task {
                    await viewModel.searchProblems()
                }
            }
            .onChange(of: viewModel.searchText) { oldValue, newValue in
                // Clear search when text is emptied (e.g. cancel tapped)
                if !oldValue.isEmpty && newValue.isEmpty {
                    Task {
                        await viewModel.searchProblems()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterButton
                }
            }
            .sheet(isPresented: $showFilters) {
                ProblemFilterView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .task {
                if viewModel.problems.isEmpty {
                    await viewModel.loadProblems()
                }
            }
        }
    }

    // MARK: - Filter Button

    private var filterButton: some View {
        Button {
            showFilters = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.body)
                    .foregroundStyle(viewModel.isFiltered ? Theme.Colors.accent : Theme.Colors.text)

                if viewModel.activeFilterCount > 0 {
                    Text("\(viewModel.activeFilterCount)")
                        .font(.system(size: 10).bold())
                        .foregroundStyle(Theme.Colors.background)
                        .frame(width: 16, height: 16)
                        .background(Theme.Colors.accent)
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }
        }
    }

    // MARK: - Problem List

    private var problemList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                // Total count header
                HStack {
                    Text("\(viewModel.totalCount) problems")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)

                ForEach(viewModel.problems) { problem in
                    NavigationLink(value: problem.titleSlug) {
                        ProblemRow(problem: problem)
                    }
                    .buttonStyle(.plain)
                    .task {
                        await viewModel.loadMoreIfNeeded(currentItem: problem)
                    }
                }

                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(Theme.Colors.accent)
                        Spacer()
                    }
                    .padding(Theme.Spacing.lg)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .refreshable {
            await viewModel.loadProblems()
        }
    }

    // MARK: - Empty / Error / Loading

    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.xl) {
            ProgressView()
                .tint(Theme.Colors.accent)
                .scaleEffect(1.2)
            Text("Loading problems...")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Theme.Colors.hard)

            Text("Something went wrong")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await viewModel.loadProblems()
                }
            }
            .foregroundStyle(Theme.Colors.accent)
            .padding(.top, Theme.Spacing.sm)
        }
        .padding(Theme.Spacing.xl)
    }

    private var emptyView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(Theme.Colors.textSecondary)

            Text("No problems found")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            if viewModel.isFiltered {
                Button("Clear Filters") {
                    Task {
                        await viewModel.clearFilters()
                    }
                }
                .foregroundStyle(Theme.Colors.accent)
            }
        }
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Problem Row

private struct ProblemRow: View {
    let problem: Problem

    private var statusIcon: String? {
        switch problem.status {
        case "ac": "checkmark.circle.fill"
        case "notac": "xmark.circle"
        default: nil
        }
    }

    private var statusColor: Color {
        switch problem.status {
        case "ac": Theme.Colors.easy
        case "notac": Theme.Colors.medium
        default: Theme.Colors.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Solved status icon
            if let icon = statusIcon {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(statusColor)
                    .frame(width: 24)
            } else {
                Circle()
                    .fill(Theme.Colors.textSecondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .frame(width: 24)
            }

            // Problem info
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(problem.title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.sm) {
                    DifficultyBadge(difficulty: problem.difficulty)

                    Text(String(format: "%.1f%%", problem.acRate))
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
    ProblemListView()
}
