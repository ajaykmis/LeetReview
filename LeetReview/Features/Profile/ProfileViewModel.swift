import Foundation
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    private(set) var profile: UserProfile?
    private(set) var recentSubmissions: [RecentSubmission] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    // MARK: - Computed Properties

    var totalSolved: Int {
        guard let stats = profile?.submitStats.acSubmissionNum else { return 0 }
        // "All" difficulty entry holds the total; fall back to summing individual counts
        if let all = stats.first(where: { $0.difficulty == "All" }) {
            return all.count
        }
        return stats.reduce(0) { $0 + $1.count }
    }

    var easySolved: Int {
        profile?.submitStats.acSubmissionNum.first(where: { $0.difficulty == "Easy" })?.count ?? 0
    }

    var mediumSolved: Int {
        profile?.submitStats.acSubmissionNum.first(where: { $0.difficulty == "Medium" })?.count ?? 0
    }

    var hardSolved: Int {
        profile?.submitStats.acSubmissionNum.first(where: { $0.difficulty == "Hard" })?.count ?? 0
    }

    var ranking: Int {
        profile?.profile.ranking ?? 0
    }

    var reputation: Int {
        profile?.profile.reputation ?? 0
    }

    // MARK: - Loading

    func loadProfile(username: String) async {
        guard !username.isEmpty else {
            errorMessage = "No username available."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let profileResult = LeetCodeAPI.shared.fetchUserProfile(username: username)
            async let submissionsResult = LeetCodeAPI.shared.fetchRecentSubmissions(username: username, limit: 15)

            let (fetchedProfile, fetchedSubmissions) = try await (profileResult, submissionsResult)
            profile = fetchedProfile
            recentSubmissions = fetchedSubmissions
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
