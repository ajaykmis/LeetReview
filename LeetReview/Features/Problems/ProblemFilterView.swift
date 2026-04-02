import SwiftUI

struct ProblemFilterView: View {
    @Bindable var viewModel: ProblemListViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    // Common LeetCode topic tags
    private static let commonTags = [
        "Array", "String", "Hash Table", "Dynamic Programming",
        "Math", "Sorting", "Greedy", "Depth-First Search",
        "Binary Search", "Breadth-First Search", "Tree", "Matrix",
        "Two Pointers", "Stack", "Bit Manipulation", "Heap (Priority Queue)",
        "Graph", "Linked List", "Sliding Window", "Backtracking",
        "Design", "Recursion", "Union Find", "Trie"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        difficultySection
                        statusSection
                        tagsSection
                    }
                    .padding(Theme.Spacing.lg)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(themeManager.toolbarColorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        viewModel.selectedDifficulty = .all
                        viewModel.selectedStatus = .all
                        viewModel.selectedTags = []
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        dismiss()
                        Task {
                            await viewModel.applyFilters()
                        }
                    }
                    .bold()
                    .foregroundStyle(Theme.Colors.accent)
                }
            }
        }
    }

    // MARK: - Difficulty

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Difficulty")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ProblemListViewModel.DifficultyFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.displayName,
                        isSelected: viewModel.selectedDifficulty == filter,
                        color: chipColor(for: filter)
                    ) {
                        viewModel.selectedDifficulty = filter
                    }
                }
            }
        }
    }

    private func chipColor(for filter: ProblemListViewModel.DifficultyFilter) -> Color {
        switch filter {
        case .all: Theme.Colors.accent
        case .easy: Theme.Colors.easy
        case .medium: Theme.Colors.medium
        case .hard: Theme.Colors.hard
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Status")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ProblemListViewModel.StatusFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.displayName,
                        isSelected: viewModel.selectedStatus == filter,
                        color: Theme.Colors.accent
                    ) {
                        viewModel.selectedStatus = filter
                    }
                }
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Tags")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.text)

                if !viewModel.selectedTags.isEmpty {
                    Text("(\(viewModel.selectedTags.count))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }

            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(Self.commonTags, id: \.self) { tag in
                    FilterChip(
                        title: tag,
                        isSelected: viewModel.selectedTags.contains(tag),
                        color: Theme.Colors.accent
                    ) {
                        if viewModel.selectedTags.contains(tag) {
                            viewModel.selectedTags.remove(tag)
                        } else {
                            viewModel.selectedTags.insert(tag)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isSelected ? Theme.Colors.background : color)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    isSelected ? color : color.opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProblemFilterView(viewModel: ProblemListViewModel())
}
