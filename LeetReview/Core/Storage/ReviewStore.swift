import Foundation
import SwiftData

// MARK: - SwiftData Model

@Model
final class ReviewItem {
    @Attribute(.unique) var titleSlug: String
    var title: String
    var difficulty: String
    var nextReviewDate: Date
    var interval: Double // in days
    var easeFactor: Double
    var repetitions: Int
    var dateAdded: Date

    init(
        titleSlug: String,
        title: String,
        difficulty: String,
        nextReviewDate: Date = .now,
        interval: Double = 1.0,
        easeFactor: Double = 2.5,
        repetitions: Int = 0,
        dateAdded: Date = .now
    ) {
        self.titleSlug = titleSlug
        self.title = title
        self.difficulty = difficulty
        self.nextReviewDate = nextReviewDate
        self.interval = interval
        self.easeFactor = easeFactor
        self.repetitions = repetitions
        self.dateAdded = dateAdded
    }
}

// MARK: - SM-2 Algorithm

enum ReviewQuality: Int, CaseIterable, Sendable {
    case again = 0 // Complete blackout
    case hard = 2  // Recalled with serious difficulty
    case good = 3  // Recalled with some hesitation
    case easy = 5  // Perfect recall

    var label: String {
        switch self {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    var color: String {
        switch self {
        case .again: "hard"    // red
        case .hard: "medium"   // yellow
        case .good: "accent"   // blue
        case .easy: "easy"     // green
        }
    }
}

enum SM2Algorithm {
    /// Applies the SM-2 spaced repetition algorithm to a review item.
    ///
    /// - Parameters:
    ///   - item: The review item to update.
    ///   - quality: The quality of recall (0-5).
    ///
    /// SM-2 rules:
    /// - If quality < 3, reset repetitions to 0 and interval to 1 day.
    /// - If quality >= 3:
    ///   - repetition 0 -> interval = 1
    ///   - repetition 1 -> interval = 6
    ///   - repetition 2+ -> interval *= easeFactor
    /// - EaseFactor adjusted: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    /// - EaseFactor minimum: 1.3
    static func update(item: ReviewItem, quality: ReviewQuality) {
        let q = Double(quality.rawValue)

        // Update ease factor using SM-2 formula
        let newEF = item.easeFactor + (0.1 - (5.0 - q) * (0.08 + (5.0 - q) * 0.02))
        item.easeFactor = max(1.3, newEF)

        if quality.rawValue < 3 {
            // Failed recall — reset
            item.repetitions = 0
            item.interval = 1.0
        } else {
            // Successful recall
            switch item.repetitions {
            case 0:
                item.interval = 1.0
            case 1:
                item.interval = 6.0
            default:
                item.interval = item.interval * item.easeFactor
            }
            item.repetitions += 1
        }

        // Schedule next review
        item.nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: max(1, Int(item.interval.rounded())),
            to: .now
        ) ?? Date.now.addingTimeInterval(86400)
    }
}

// MARK: - Review Store (data access layer)

@MainActor
final class ReviewStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Add a problem to the review queue. If it already exists, do nothing.
    func addProblem(titleSlug: String, title: String, difficulty: String) {
        // Check if already exists
        let predicate = #Predicate<ReviewItem> { item in
            item.titleSlug == titleSlug
        }
        let descriptor = FetchDescriptor<ReviewItem>(predicate: predicate)

        do {
            let existing = try modelContext.fetch(descriptor)
            guard existing.isEmpty else { return }
        } catch {
            // If fetch fails, try to insert anyway
        }

        let item = ReviewItem(
            titleSlug: titleSlug,
            title: title,
            difficulty: difficulty
        )
        modelContext.insert(item)
        try? modelContext.save()
    }

    /// Returns review items that are due (nextReviewDate <= now), ordered by next review date.
    func getDueItems() -> [ReviewItem] {
        let now = Date.now
        let predicate = #Predicate<ReviewItem> { item in
            item.nextReviewDate <= now
        }
        var descriptor = FetchDescriptor<ReviewItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.nextReviewDate, order: .forward)]
        )
        descriptor.fetchLimit = 100

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    /// Returns all review items, ordered by next review date.
    func getAllItems() -> [ReviewItem] {
        let descriptor = FetchDescriptor<ReviewItem>(
            sortBy: [SortDescriptor(\.nextReviewDate, order: .forward)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    /// Returns the total count of review items.
    func totalCount() -> Int {
        let descriptor = FetchDescriptor<ReviewItem>()
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            return 0
        }
    }

    /// Update a review item after the user rates their recall.
    func updateReview(item: ReviewItem, quality: ReviewQuality) {
        SM2Algorithm.update(item: item, quality: quality)
        try? modelContext.save()
    }

    /// Remove a problem from the review queue.
    func removeItem(_ item: ReviewItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    /// Find a review item by its title slug.
    func findItem(bySlug titleSlug: String) -> ReviewItem? {
        let predicate = #Predicate<ReviewItem> { item in
            item.titleSlug == titleSlug
        }
        let descriptor = FetchDescriptor<ReviewItem>(predicate: predicate)

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            return nil
        }
    }
}
