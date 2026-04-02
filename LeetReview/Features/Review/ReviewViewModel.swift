import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ReviewViewModel {
    // MARK: - State

    private(set) var dueItems: [ReviewItem] = []
    private(set) var currentIndex: Int = 0
    private(set) var isFlipped: Bool = false
    private(set) var isLoadingCode: Bool = false
    private(set) var currentCode: String?
    private(set) var currentLang: String?
    private(set) var errorMessage: String?
    private(set) var sessionComplete: Bool = false
    private(set) var reviewedCount: Int = 0

    var totalDueCount: Int { dueItems.count + reviewedCount }

    var currentItem: ReviewItem? {
        guard currentIndex < dueItems.count else { return nil }
        return dueItems[currentIndex]
    }

    var hasItems: Bool { !dueItems.isEmpty }

    var totalInQueue: Int {
        reviewStore?.totalCount() ?? 0
    }

    var progressText: String {
        if totalDueCount == 0 { return "No reviews" }
        return "\(reviewedCount) of \(totalDueCount) reviewed"
    }

    var progressFraction: Double {
        guard totalDueCount > 0 else { return 0 }
        return Double(reviewedCount) / Double(totalDueCount)
    }

    private var reviewStore: ReviewStore?

    // MARK: - Setup

    func configure(modelContext: ModelContext) {
        self.reviewStore = ReviewStore(modelContext: modelContext)
    }

    // MARK: - Loading

    func loadDueItems() {
        guard let store = reviewStore else { return }
        dueItems = store.getDueItems()
        currentIndex = 0
        isFlipped = false
        currentCode = nil
        currentLang = nil
        sessionComplete = dueItems.isEmpty
        reviewedCount = 0
        errorMessage = nil
    }

    // MARK: - Card Interaction

    func showSolution() async {
        guard let item = currentItem else { return }

        isFlipped = true

        // Check cache first
        if let cachedCode = CacheManager.shared.get(key: "review_code_\(item.titleSlug)", as: CachedSubmissionCode.self) {
            currentCode = cachedCode.code
            currentLang = cachedCode.lang
            return
        }

        isLoadingCode = true
        errorMessage = nil

        do {
            // Fetch the user's submissions for this problem
            let submissions = try await LeetCodeAPI.shared.fetchSubmissions(
                questionSlug: item.titleSlug,
                limit: 5
            )

            // Find the most recent Accepted submission
            let accepted = submissions.first { $0.statusDisplay == "Accepted" }
            ?? submissions.first

            if let submission = accepted, let submissionId = Int(submission.id) {
                let detail = try await LeetCodeAPI.shared.fetchSubmissionDetail(
                    submissionId: submissionId
                )
                currentCode = detail.code
                currentLang = detail.lang

                // Cache for offline access
                let cached = CachedSubmissionCode(code: detail.code, lang: detail.lang)
                CacheManager.shared.cache(key: "review_code_\(item.titleSlug)", value: cached)
            } else {
                currentCode = "// No submissions found for this problem"
                currentLang = nil
            }
        } catch {
            errorMessage = "Failed to load solution: \(error.localizedDescription)"
            currentCode = "// Error loading code. Check your connection."
            currentLang = nil
        }

        isLoadingCode = false
    }

    func rate(quality: ReviewQuality) {
        guard let item = currentItem, let store = reviewStore else { return }

        // Apply SM-2 algorithm
        store.updateReview(item: item, quality: quality)

        reviewedCount += 1

        // If the item was rated "Again", it will show up again next time
        // For now, just move to the next card in this session
        // Remove from dueItems since we've reviewed it
        dueItems.remove(at: currentIndex)

        // Reset card state for next item
        isFlipped = false
        currentCode = nil
        currentLang = nil
        errorMessage = nil

        // Adjust index (stay at same index since we removed current)
        if currentIndex >= dueItems.count {
            currentIndex = 0
        }

        if dueItems.isEmpty {
            sessionComplete = true
        }
    }

    func resetSession() {
        loadDueItems()
    }

    // MARK: - Add Problem to Review

    func addProblemToReview(titleSlug: String, title: String, difficulty: String) {
        guard let store = reviewStore else { return }
        store.addProblem(titleSlug: titleSlug, title: title, difficulty: difficulty)
    }

    // MARK: - Navigate to Problem by Slug (URL scheme)

    func navigateToProblem(slug: String) {
        guard let store = reviewStore else { return }

        // If item exists in review, jump to it
        if let item = store.findItem(bySlug: slug) {
            if let index = dueItems.firstIndex(where: { $0.titleSlug == slug }) {
                currentIndex = index
                isFlipped = false
                currentCode = nil
                currentLang = nil
            } else {
                // Item exists but isn't due — force reload with it
                dueItems = [item]
                currentIndex = 0
                isFlipped = false
                currentCode = nil
                currentLang = nil
                sessionComplete = false
            }
        }
    }
}

// MARK: - Cached Code Model

private struct CachedSubmissionCode: Codable {
    let code: String
    let lang: String
}
