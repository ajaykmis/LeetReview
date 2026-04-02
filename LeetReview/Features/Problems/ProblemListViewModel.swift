import Foundation
import Observation

@Observable
@MainActor
final class ProblemListViewModel {
    // MARK: - State

    private(set) var problems: [Problem] = []
    private(set) var totalCount = 0
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    var searchText = ""
    var selectedDifficulty: DifficultyFilter = .all
    var selectedStatus: StatusFilter = .all
    var selectedTags: Set<String> = []

    private let pageSize = 30
    private var currentSkip = 0
    private var hasMorePages: Bool { currentSkip < totalCount }

    // MARK: - Filter Types

    enum DifficultyFilter: String, CaseIterable, Sendable {
        case all = "All"
        case easy = "EASY"
        case medium = "MEDIUM"
        case hard = "HARD"

        var displayName: String {
            switch self {
            case .all: "All"
            case .easy: "Easy"
            case .medium: "Medium"
            case .hard: "Hard"
            }
        }
    }

    enum StatusFilter: String, CaseIterable, Sendable {
        case all = "All"
        case todo = "NOT_STARTED"
        case solved = "AC"
        case attempted = "TRIED"

        var displayName: String {
            switch self {
            case .all: "All"
            case .todo: "Todo"
            case .solved: "Solved"
            case .attempted: "Attempted"
            }
        }
    }

    // MARK: - Computed

    var isFiltered: Bool {
        selectedDifficulty != .all || selectedStatus != .all || !selectedTags.isEmpty
    }

    var activeFilterCount: Int {
        var count = 0
        if selectedDifficulty != .all { count += 1 }
        if selectedStatus != .all { count += 1 }
        count += selectedTags.count
        return count
    }

    // MARK: - Data Loading

    func loadProblems() async {
        isLoading = true
        errorMessage = nil
        currentSkip = 0

        let difficulty = selectedDifficulty != .all ? selectedDifficulty.rawValue : nil
        let status = selectedStatus != .all ? selectedStatus.rawValue : nil
        let search = searchText.trimmingCharacters(in: .whitespaces)
        let tags = selectedTags.isEmpty ? nil : Array(selectedTags)

        do {
            let result = try await LeetCodeAPI.shared.fetchProblemList(
                limit: pageSize,
                skip: 0,
                difficulty: difficulty,
                status: status,
                searchKeywords: search.isEmpty ? nil : search,
                tags: tags
            )
            problems = result.questions
            totalCount = result.total
            currentSkip = result.questions.count
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreIfNeeded(currentItem: Problem) async {
        guard !isLoadingMore, hasMorePages else { return }

        let thresholdIndex = problems.index(problems.endIndex, offsetBy: -5, limitedBy: problems.startIndex) ?? problems.startIndex
        guard let itemIndex = problems.firstIndex(where: { $0.id == currentItem.id }),
              itemIndex >= thresholdIndex else { return }

        isLoadingMore = true

        let difficulty = selectedDifficulty != .all ? selectedDifficulty.rawValue : nil
        let status = selectedStatus != .all ? selectedStatus.rawValue : nil
        let search = searchText.trimmingCharacters(in: .whitespaces)
        let tags = selectedTags.isEmpty ? nil : Array(selectedTags)
        let skip = currentSkip

        do {
            let result = try await LeetCodeAPI.shared.fetchProblemList(
                limit: pageSize,
                skip: skip,
                difficulty: difficulty,
                status: status,
                searchKeywords: search.isEmpty ? nil : search,
                tags: tags
            )
            problems.append(contentsOf: result.questions)
            totalCount = result.total
            currentSkip += result.questions.count
        } catch {
            // Silently fail for pagination — user can scroll to retry
        }

        isLoadingMore = false
    }

    func searchProblems() async {
        await loadProblems()
    }

    func applyFilters() async {
        await loadProblems()
    }

    func clearFilters() async {
        selectedDifficulty = .all
        selectedStatus = .all
        selectedTags = []
        await loadProblems()
    }
}
