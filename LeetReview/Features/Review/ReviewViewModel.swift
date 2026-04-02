import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ReviewViewModel {
    // MARK: - State

    private(set) var dueItems: [ReviewItem] = []
    private(set) var allItems: [ReviewItem] = []
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

    var upcomingItems: [ReviewItem] {
        let now = Date.now
        return allItems
            .filter { $0.nextReviewDate > now }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
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
        loadAllItems()
    }

    func loadAllItems() {
        guard let store = reviewStore else { return }
        allItems = store.getAllItems()
    }

    // MARK: - Card Interaction

    func showSolution() async {
        guard let item = currentItem else { return }

        isFlipped = true

        // Check cache first
        if let cachedCode = await CacheManager.shared.get(key: "review_code_\(item.titleSlug)", as: CachedSubmissionCode.self) {
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
                await CacheManager.shared.cache(key: "review_code_\(item.titleSlug)", value: cached)
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

    /// Load solution code for a specific item (used by queue view's "Show Solution" action).
    func loadSolutionCode(for item: ReviewItem) async -> (code: String, lang: String?) {
        // Check cache first
        if let cachedCode = await CacheManager.shared.get(key: "review_code_\(item.titleSlug)", as: CachedSubmissionCode.self) {
            return (cachedCode.code, cachedCode.lang)
        }

        do {
            let submissions = try await LeetCodeAPI.shared.fetchSubmissions(
                questionSlug: item.titleSlug,
                limit: 5
            )

            let accepted = submissions.first { $0.statusDisplay == "Accepted" }
            ?? submissions.first

            if let submission = accepted, let submissionId = Int(submission.id) {
                let detail = try await LeetCodeAPI.shared.fetchSubmissionDetail(
                    submissionId: submissionId
                )

                let cached = CachedSubmissionCode(code: detail.code, lang: detail.lang)
                await CacheManager.shared.cache(key: "review_code_\(item.titleSlug)", value: cached)

                return (detail.code, detail.lang)
            } else {
                return ("// No submissions found for this problem", nil)
            }
        } catch {
            return ("// Error loading code: \(error.localizedDescription)", nil)
        }
    }

    func rate(quality: ReviewQuality) {
        guard let item = currentItem, let store = reviewStore else { return }

        // Apply SM-2 algorithm
        store.updateReview(item: item, quality: quality)

        reviewedCount += 1

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

        // Refresh all items to reflect updated review dates
        loadAllItems()
    }

    func resetSession() {
        loadDueItems()
    }

    // MARK: - Dismiss Item

    func dismissItem(_ item: ReviewItem) {
        guard let store = reviewStore else { return }
        store.removeItem(item)
        dueItems.removeAll { $0.titleSlug == item.titleSlug }
        allItems.removeAll { $0.titleSlug == item.titleSlug }
    }

    // MARK: - Relative Due Date

    func relativeDueDate(for item: ReviewItem) -> String {
        let now = Date.now
        let dueDate = item.nextReviewDate
        let interval = dueDate.timeIntervalSince(now)

        if interval <= 0 {
            // Overdue or due now
            let overdue = abs(interval)
            if overdue < 60 {
                return "Due now"
            } else if overdue < 3600 {
                let mins = Int(overdue / 60)
                return "Overdue \(mins)m"
            } else if overdue < 86400 {
                let hours = Int(overdue / 3600)
                return "Overdue \(hours)h"
            } else {
                let days = Int(overdue / 86400)
                return "Overdue \(days)d"
            }
        } else {
            // Upcoming
            if interval < 3600 {
                let mins = Int(interval / 60)
                return "Due in \(mins)m"
            } else if interval < 86400 {
                let hours = Int(interval / 3600)
                return "Due in \(hours)h"
            } else if interval < 172800 {
                return "Due tomorrow"
            } else {
                let days = Int(interval / 86400)
                return "Due in \(days)d"
            }
        }
    }

    // MARK: - Preview Interval

    /// Computes what the next interval would be if the item were rated with the given quality,
    /// without actually modifying the item.
    func previewInterval(for item: ReviewItem, quality: ReviewQuality) -> String {
        let q = Double(quality.rawValue)

        let newEF = max(1.3, item.easeFactor + (0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02)))

        let newInterval: Double
        if quality.rawValue < 3 {
            // Failed recall -- reset
            newInterval = 1.0
        } else {
            switch item.repetitions {
            case 0:
                newInterval = 1.0
            case 1:
                newInterval = 6.0
            default:
                newInterval = item.interval * newEF
            }
        }

        return formatInterval(newInterval)
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
                // Item exists but isn't due -- force reload with it
                dueItems = [item]
                currentIndex = 0
                isFlipped = false
                currentCode = nil
                currentLang = nil
                sessionComplete = false
            }
        }
    }

    // MARK: - Helpers

    private func formatInterval(_ interval: Double) -> String {
        if interval < 1 {
            return "<1d"
        } else if interval < 30 {
            return "\(Int(interval.rounded()))d"
        } else if interval < 365 {
            let months = interval / 30.0
            return String(format: "%.1fmo", months)
        } else {
            let years = interval / 365.0
            return String(format: "%.1fy", years)
        }
    }
}

// MARK: - Cached Code Model

private struct CachedSubmissionCode: Codable {
    let code: String
    let lang: String
}
