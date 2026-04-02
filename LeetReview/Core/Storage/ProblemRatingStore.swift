import Foundation

/// Loads and caches community difficulty ratings for LeetCode problems.
/// Ratings are numeric scores (800-3000+) sourced from zerotrac's dataset.
actor ProblemRatingStore {
    static let shared = ProblemRatingStore()

    private var ratings: [String: Int]?
    private var isLoading = false

    private static let cacheKey = "problem_ratings_data"
    private static let remoteURL = URL(string: "https://zerotrac.github.io/leetcode_problem_rating/data.json")!

    private init() {}

    // MARK: - Public API

    /// Returns the community rating for a given problem, or nil if unavailable.
    func rating(for titleSlug: String) async -> Int? {
        if ratings == nil {
            await loadRatings()
        }
        return ratings?[titleSlug]
    }

    /// Returns all loaded ratings as a dictionary mapping titleSlug to rating.
    func allRatings() async -> [String: Int] {
        if ratings == nil {
            await loadRatings()
        }
        return ratings ?? [:]
    }

    /// Fetches ratings from cache or remote and stores them.
    func loadRatings() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Try cache first
        if let cached = await CacheManager.shared.get(key: Self.cacheKey, as: [String: Int].self) {
            ratings = cached
            // Refresh in background without blocking
            Task { await refreshFromRemote() }
            return
        }

        // No cache — fetch from remote
        await refreshFromRemote()
    }

    // MARK: - Private

    private func refreshFromRemote() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: Self.remoteURL)
            let parsed = try parseRatings(from: data)
            ratings = parsed
            await CacheManager.shared.cache(key: Self.cacheKey, value: parsed)
        } catch {
            // If fetch fails and we already have cached data, keep it.
            // If no cached data either, ratings stays nil — callers get nil gracefully.
        }
    }

    private func parseRatings(from data: Data) throws -> [String: Int] {
        let entries = try JSONDecoder().decode([RatingEntry].self, from: data)
        var map: [String: Int] = [:]
        map.reserveCapacity(entries.count)
        for entry in entries {
            map[entry.TitleSlug] = Int(entry.Rating.rounded())
        }
        return map
    }
}

// MARK: - Remote Data Model

private struct RatingEntry: Decodable {
    let TitleSlug: String
    let Rating: Double
}
