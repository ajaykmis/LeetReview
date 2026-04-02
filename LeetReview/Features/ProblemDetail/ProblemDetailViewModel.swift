import Foundation
import Observation

@Observable
@MainActor
final class ProblemDetailViewModel {
    private(set) var detail: ProblemDetail?
    private(set) var submissions: [Submission] = []
    private(set) var isLoadingDetail = false
    private(set) var isLoadingSubmissions = false
    private(set) var detailError: String?
    private(set) var submissionsError: String?

    let titleSlug: String
    let title: String

    init(titleSlug: String, title: String) {
        self.titleSlug = titleSlug
        self.title = title
    }

    // MARK: - Fetch Problem Detail

    func loadDetail() async {
        guard detail == nil, !isLoadingDetail else { return }
        isLoadingDetail = true
        detailError = nil

        do {
            detail = try await LeetCodeAPI.shared.fetchProblemDetail(titleSlug: titleSlug)
        } catch {
            detailError = error.localizedDescription
        }

        isLoadingDetail = false
    }

    // MARK: - Fetch Submissions

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

    // MARK: - Load All

    func loadAll() async {
        async let detailTask: () = loadDetail()
        async let submissionsTask: () = loadSubmissions()
        _ = await (detailTask, submissionsTask)
    }

    // MARK: - Parsed Stats

    /// Parses the `stats` JSON string from ProblemDetail to extract acceptance rate.
    var acceptanceRate: String? {
        guard let statsJSON = detail?.stats,
              let data = statsJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rate = dict["acRate"] as? String else {
            return nil
        }
        return rate
    }

    /// Total submissions count from parsed stats.
    var totalSubmissions: String? {
        guard let statsJSON = detail?.stats,
              let data = statsJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let total = dict["totalSubmissionRaw"] as? Int else {
            return nil
        }

        if total >= 1_000_000 {
            return String(format: "%.1fM", Double(total) / 1_000_000)
        } else if total >= 1_000 {
            return String(format: "%.1fK", Double(total) / 1_000)
        }
        return "\(total)"
    }

    /// Total accepted count from parsed stats.
    var totalAccepted: String? {
        guard let statsJSON = detail?.stats,
              let data = statsJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let total = dict["totalAcceptedRaw"] as? Int else {
            return nil
        }

        if total >= 1_000_000 {
            return String(format: "%.1fM", Double(total) / 1_000_000)
        } else if total >= 1_000 {
            return String(format: "%.1fK", Double(total) / 1_000)
        }
        return "\(total)"
    }
}
