import Foundation
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    private(set) var profile: UserProfile?
    private(set) var recentSubmissions: [RecentSubmission] = []
    private(set) var contestRanking: ContestRankingInfo?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var avatarURL: URL? {
        guard let urlString = profile?.profile.userAvatar, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }

    var realName: String? {
        profile?.profile.realName?.isEmpty == false ? profile?.profile.realName : nil
    }

    var company: String? {
        profile?.profile.company?.isEmpty == false ? profile?.profile.company : nil
    }

    var school: String? {
        profile?.profile.school?.isEmpty == false ? profile?.profile.school : nil
    }

    var totalSolved: Int {
        guard let stats = profile?.submitStats.acSubmissionNum else { return 0 }
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

    var activeDaysCount: Int {
        Set<String>(recentSubmissions.compactMap { submission in
            guard let date = Date.fromTimestamp(submission.timestamp) else {
                return nil
            }
            return dayStamp(for: date)
        }).count
    }

    var languageBreakdown: [LanguageBreakdown] {
        let grouped = Dictionary(grouping: recentSubmissions, by: \.lang)
        return grouped.map { key, value in
            LanguageBreakdown(language: key, count: value.count)
        }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.language < rhs.language
            }
            return lhs.count > rhs.count
        }
    }

    var heatmapDays: [SubmissionHeatmapDay] {
        let today = Calendar.current.startOfDay(for: Date.now)
        let grouped = Dictionary(grouping: recentSubmissions.compactMap { submission -> Date? in
            guard let date = Date.fromTimestamp(submission.timestamp) else {
                return nil
            }
            return Calendar.current.startOfDay(for: date)
        }, by: { $0 })

        return (0..<56).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: today) ?? today
            let count = grouped[date]?.count ?? 0
            let intensity = min(count, 4)
            return SubmissionHeatmapDay(date: date, intensity: intensity, count: count)
        }
    }

    var weeklyGoalProgress: Double {
        min(Double(activeDaysCount) / 5.0, 1.0)
    }

    var momentumHeadline: String {
        if recentSubmissions.isEmpty {
            return "No recent accepted submissions yet."
        }
        if activeDaysCount >= 5 {
            return "Strong weekly consistency."
        }
        if activeDaysCount >= 3 {
            return "Good recent momentum."
        }
        return "Light recent activity."
    }

    var nextFocus: String {
        let tuple = [("Easy", easySolved), ("Medium", mediumSolved), ("Hard", hardSolved)]
            .sorted { $0.1 < $1.1 }
            .first
        return tuple?.0 ?? "Medium"
    }

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
            async let contestResult = LeetCodeAPI.shared.fetchContestRanking(username: username)

            let (fetchedProfile, fetchedSubmissions, fetchedContest) = try await (profileResult, submissionsResult, contestResult)
            profile = fetchedProfile
            recentSubmissions = fetchedSubmissions
            contestRanking = fetchedContest
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func dayStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct SubmissionHeatmapDay: Identifiable {
    let date: Date
    let intensity: Int
    let count: Int

    var id: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct LanguageBreakdown: Identifiable {
    let language: String
    let count: Int

    var id: String { language }
}
