import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    // MARK: - State

    private(set) var dailyChallenge: DailyChallenge?
    private(set) var upcomingContests: [Contest] = []
    private(set) var userProfile: UserProfile?
    private(set) var recentSubmissions: [RecentSubmission] = []

    private(set) var isLoading = false
    private(set) var errorMessage: String?

    // Computed stats from profile
    var easySolved: Int {
        userProfile?.submitStats.acSubmissionNum
            .first(where: { $0.difficulty == "Easy" })?.count ?? 0
    }

    var mediumSolved: Int {
        userProfile?.submitStats.acSubmissionNum
            .first(where: { $0.difficulty == "Medium" })?.count ?? 0
    }

    var hardSolved: Int {
        userProfile?.submitStats.acSubmissionNum
            .first(where: { $0.difficulty == "Hard" })?.count ?? 0
    }

    var totalSolved: Int {
        userProfile?.submitStats.acSubmissionNum
            .first(where: { $0.difficulty == "All" })?.count ?? (easySolved + mediumSolved + hardSolved)
    }

    // MARK: - Data Loading

    func loadDashboard(username: String?) async {
        isLoading = true
        errorMessage = nil

        async let challengeTask: () = loadDailyChallenge()
        async let contestsTask: () = loadUpcomingContests()

        // Only fetch user-specific data if we have a username
        if let username {
            async let profileTask: () = loadUserProfile(username: username)
            async let recentTask: () = loadRecentSubmissions(username: username)
            _ = await (challengeTask, contestsTask, profileTask, recentTask)
        } else {
            _ = await (challengeTask, contestsTask)
        }

        isLoading = false
    }

    private func loadDailyChallenge() async {
        do {
            dailyChallenge = try await LeetCodeAPI.shared.fetchDailyChallenge()
        } catch {
            // Non-critical — dashboard still works without daily challenge
        }
    }

    private func loadUpcomingContests() async {
        do {
            upcomingContests = try await LeetCodeAPI.shared.fetchUpcomingContests()
        } catch {
            // Non-critical
        }
    }

    private func loadUserProfile(username: String) async {
        do {
            userProfile = try await LeetCodeAPI.shared.fetchUserProfile(username: username)
        } catch {
            errorMessage = "Failed to load profile stats."
        }
    }

    private func loadRecentSubmissions(username: String) async {
        do {
            recentSubmissions = try await LeetCodeAPI.shared.fetchRecentSubmissions(
                username: username,
                limit: 10
            )
        } catch {
            // Non-critical
        }
    }
}
