import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ProblemDetailViewModel {
    enum DetailSection: String, CaseIterable, Identifiable {
        case description = "Description"
        case hints = "Hints"
        case editorial = "Editorial"
        case community = "Community"
        case similar = "Similar"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .description: "doc.text"
            case .hints: "lightbulb"
            case .editorial: "book.pages"
            case .community: "bubble.left.and.bubble.right"
            case .similar: "square.grid.2x2"
            }
        }
    }

    // MARK: - Core state

    private(set) var detail: ProblemDetail?
    private(set) var submissions: [Submission] = []
    private(set) var isLoadingDetail = false
    private(set) var isLoadingSubmissions = false
    private(set) var detailError: String?
    private(set) var submissionsError: String?

    // MARK: - Tab section data (real API)

    private(set) var hints: [String] = []
    private(set) var isLoadingHints = false

    private(set) var editorialSolution: OfficialSolution?
    private(set) var isLoadingEditorial = false
    private(set) var editorialError: String?

    private(set) var communitySolutions: [CommunitySolution] = []
    private(set) var communityTotal: Int = 0
    private(set) var isLoadingCommunity = false
    private(set) var communityError: String?

    private(set) var similarQuestions: [SimilarQuestion] = []
    private(set) var isLoadingSimilar = false
    private(set) var similarError: String?

    // MARK: - Offline support

    private(set) var isSavedOffline = false
    private var offlineManager: OfflineManager?

    // MARK: - Review integration

    private(set) var addedToReview = false
    private var reviewStore: ReviewStore?

    // MARK: - Section selection

    var selectedSection: DetailSection = .description {
        didSet {
            if oldValue != selectedSection {
                Task { await loadSectionIfNeeded(selectedSection) }
            }
        }
    }

    let titleSlug: String
    let title: String

    // Track which sections have been loaded
    private var loadedSections: Set<DetailSection> = []

    init(titleSlug: String, title: String) {
        self.titleSlug = titleSlug
        self.title = title
    }

    func configureOffline(offlineManager: OfflineManager) {
        self.offlineManager = offlineManager
        isSavedOffline = offlineManager.isSaved(titleSlug: titleSlug)
    }

    func configureReview(modelContext: ModelContext) {
        self.reviewStore = ReviewStore(modelContext: modelContext)
        checkReviewStatus()
    }

    // MARK: - Loading

    func loadDetail() async {
        guard detail == nil, !isLoadingDetail else { return }
        isLoadingDetail = true
        detailError = nil

        // Check cache first
        let cacheKey = CacheManager.problemDetailKey(titleSlug)
        if let cached = await CacheManager.shared.get(key: cacheKey, as: ProblemDetail.self) {
            detail = cached
            if let inlineHints = cached.hints, !inlineHints.isEmpty {
                hints = inlineHints
                loadedSections.insert(.hints)
            }
            isLoadingDetail = false
            // Skip background refresh when offline
            let isCurrentlyOffline = offlineManager?.isOffline ?? false
            if !isCurrentlyOffline {
                Task {
                    if let fresh = try? await LeetCodeAPI.shared.fetchProblemDetail(titleSlug: titleSlug) {
                        detail = fresh
                        await CacheManager.shared.cache(key: cacheKey, value: fresh)
                        if let inlineHints = fresh.hints, !inlineHints.isEmpty {
                            hints = inlineHints
                            loadedSections.insert(.hints)
                        }
                    }
                }
            }
            return
        }

        do {
            let fetchedDetail = try await LeetCodeAPI.shared.fetchProblemDetail(titleSlug: titleSlug)
            detail = fetchedDetail
            await CacheManager.shared.cache(key: cacheKey, value: fetchedDetail)
            // Hints come inline with the detail response
            if let inlineHints = fetchedDetail.hints, !inlineHints.isEmpty {
                hints = inlineHints
                loadedSections.insert(.hints)
            }
        } catch {
            detailError = error.localizedDescription
        }

        isLoadingDetail = false
    }

    func loadSubmissions() async {
        guard !isLoadingSubmissions else { return }
        isLoadingSubmissions = true
        submissionsError = nil

        do {
            submissions = try await LeetCodeAPI.shared.fetchSubmissions(questionSlug: titleSlug)
        } catch {
            submissionsError = error.localizedDescription
        }

        isLoadingSubmissions = false
    }

    func loadAll() async {
        async let detailTask: () = loadDetail()
        async let submissionsTask: () = loadSubmissions()
        _ = await (detailTask, submissionsTask)
    }

    // MARK: - Lazy section loading

    func loadSectionIfNeeded(_ section: DetailSection) async {
        guard !loadedSections.contains(section) else { return }
        switch section {
        case .description:
            break // loaded with detail
        case .hints:
            await loadHints()
        case .editorial:
            await loadEditorial()
        case .community:
            await loadCommunitySolutions()
        case .similar:
            await loadSimilarQuestions()
        }
    }

    private func loadHints() async {
        guard hints.isEmpty, !isLoadingHints else { return }
        isLoadingHints = true
        do {
            hints = try await LeetCodeAPI.shared.fetchQuestionHints(titleSlug: titleSlug)
            loadedSections.insert(.hints)
        } catch {
            // Hints are optional — fail silently
        }
        isLoadingHints = false
    }

    private func loadEditorial() async {
        guard editorialSolution == nil, !isLoadingEditorial else { return }
        isLoadingEditorial = true
        editorialError = nil
        do {
            editorialSolution = try await LeetCodeAPI.shared.fetchOfficialSolution(titleSlug: titleSlug)
            loadedSections.insert(.editorial)
        } catch {
            editorialError = error.localizedDescription
        }
        isLoadingEditorial = false
    }

    private func loadCommunitySolutions() async {
        guard communitySolutions.isEmpty, !isLoadingCommunity else { return }
        isLoadingCommunity = true
        communityError = nil
        do {
            let result = try await LeetCodeAPI.shared.fetchCommunitySolutions(
                questionSlug: titleSlug,
                first: 10,
                orderBy: "most_votes"
            )
            communitySolutions = result.solutions
            communityTotal = result.totalNum
            loadedSections.insert(.community)
        } catch {
            communityError = error.localizedDescription
        }
        isLoadingCommunity = false
    }

    private func loadSimilarQuestions() async {
        guard similarQuestions.isEmpty, !isLoadingSimilar else { return }
        isLoadingSimilar = true
        similarError = nil
        do {
            similarQuestions = try await LeetCodeAPI.shared.fetchSimilarQuestions(titleSlug: titleSlug)
            loadedSections.insert(.similar)
        } catch {
            similarError = error.localizedDescription
        }
        isLoadingSimilar = false
    }

    // MARK: - Review

    func addToReview() {
        guard let detail, let store = reviewStore else { return }
        store.addProblem(
            titleSlug: titleSlug,
            title: detail.title ?? title,
            difficulty: detail.difficulty
        )
        addedToReview = true
    }

    private func checkReviewStatus() {
        guard let store = reviewStore else { return }
        addedToReview = store.findItem(bySlug: titleSlug) != nil
    }

    // MARK: - Offline

    func toggleSaveOffline() {
        guard let offlineManager else { return }
        if isSavedOffline {
            offlineManager.removeSavedProblem(titleSlug: titleSlug)
            isSavedOffline = false
        } else {
            offlineManager.saveProblemForOffline(titleSlug: titleSlug)
            isSavedOffline = true
            // Ensure the detail is fully cached
            if let detail {
                let cacheKey = CacheManager.problemDetailKey(titleSlug)
                Task {
                    await CacheManager.shared.cache(key: cacheKey, value: detail)
                }
            }
        }
    }

    // MARK: - Computed helpers

    var acceptanceRate: String? {
        guard let statsJSON = detail?.stats,
              let data = statsJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rate = dict["acRate"] as? String else {
            return nil
        }
        return rate
    }

    var totalSubmissions: String? {
        guard let total = statValue(for: "totalSubmissionRaw") else {
            return nil
        }
        return formatMetric(total)
    }

    var totalAccepted: String? {
        guard let total = statValue(for: "totalAcceptedRaw") else {
            return nil
        }
        return formatMetric(total)
    }

    var editorProblem: CodeEditorProblemSnapshot? {
        guard let detail else { return nil }
        return CodeEditorProblemSnapshot(detail: detail, fallbackTitle: title)
    }

    var canOpenEditor: Bool {
        editorProblem != nil
    }

    var editorLanguageCount: Int {
        editorProblem?.starterCodes.count ?? 0
    }

    var insightSummary: String {
        let difficulty = detail?.difficulty ?? "Unknown"
        let tags = detail?.topicTags.prefix(2).map(\.name).joined(separator: " + ") ?? "core data structures"
        return "\(difficulty) problem centered on \(tags). Start by identifying the state you need to preserve before writing code."
    }

    private func statValue(for key: String) -> Int? {
        guard let statsJSON = detail?.stats,
              let data = statsJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let total = dict[key] as? Int else {
            return nil
        }
        return total
    }

    private func formatMetric(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}
