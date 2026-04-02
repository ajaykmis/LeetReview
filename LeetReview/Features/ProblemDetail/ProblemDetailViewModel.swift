import Foundation
import Observation

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

    private(set) var detail: ProblemDetail?
    private(set) var submissions: [Submission] = []
    private(set) var isLoadingDetail = false
    private(set) var isLoadingSubmissions = false
    private(set) var detailError: String?
    private(set) var submissionsError: String?

    var selectedSection: DetailSection = .description

    let titleSlug: String
    let title: String

    init(titleSlug: String, title: String) {
        self.titleSlug = titleSlug
        self.title = title
    }

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

    var generatedHints: [String] {
        var hints = [
            "Rephrase the problem in terms of what changes from one state to the next.",
            "Use the topic tags to narrow the solution family before choosing an implementation."
        ]

        if let difficulty = detail?.difficulty {
            switch difficulty.lowercased() {
            case "easy":
                hints.append("Aim for the simplest correct pass first, then trim extra work if needed.")
            case "medium":
                hints.append("Check whether a hash map, stack, or two-pointer invariant removes nested loops.")
            case "hard":
                hints.append("Focus on the invariant or recurrence before touching edge cases.")
            default:
                break
            }
        }

        if let firstTag = detail?.topicTags.first?.name {
            hints.append("If \(firstTag.lowercased()) is the dominant pattern, sketch a small example and track that structure by hand.")
        }

        return Array(hints.prefix(4))
    }

    var editorialSummary: String {
        let acceptance = acceptanceRate ?? "n/a"
        return "Editorial content is not wired yet, but this shell mirrors the Flutter structure. Current signal: \(acceptance) acceptance, \(detail?.difficulty ?? "unknown") difficulty, and \(submissions.count) local submission(s)."
    }

    var editorialChecklist: [String] {
        [
            "Identify the core pattern from the topic tags before writing code.",
            "Define the input-output invariant for your main loop or recursion.",
            "Confirm the target time complexity against the problem difficulty.",
            "Stress-test the approach with the smallest and most repetitive edge cases."
        ]
    }

    var communityHighlights: [ProblemDetailCommunityHighlight] {
        let tags = detail?.topicTags.map(\.name) ?? []
        let seedTags = Array(tags.prefix(3))
        let fallback = ["Pattern tradeoffs", "Edge-case traps", "Complexity notes"]
        let topics = seedTags.isEmpty ? fallback : seedTags

        return topics.enumerated().map { index, topic in
            ProblemDetailCommunityHighlight(
                title: topic,
                body: communityBody(for: topic, index: index)
            )
        }
    }

    var similarQuestionShell: [ProblemDetailSimilarQuestion] {
        let tags = detail?.topicTags.map(\.name) ?? []
        let seedTags = Array(tags.prefix(4))

        if seedTags.isEmpty {
            return [
                ProblemDetailSimilarQuestion(title: "Similar questions will appear here", subtitle: "Main app hook needed: fetch similar questions by slug."),
                ProblemDetailSimilarQuestion(title: "Topic-based practice queue", subtitle: "Use the active tags once the similar-question API is added."),
                ProblemDetailSimilarQuestion(title: "Follow-up difficulty ladder", subtitle: "Show easy-medium-hard progressions from the same concept family.")
            ]
        }

        return seedTags.map { tag in
            ProblemDetailSimilarQuestion(
                title: "\(tag) follow-up set",
                subtitle: "Use \(tag.lowercased()) to queue adjacent problems once the network hook lands."
            )
        }
    }

    private func communityBody(for topic: String, index: Int) -> String {
        switch index {
        case 0:
            return "Expect high-signal posts about why \(topic.lowercased()) beats the naive approach and where the common branching mistakes happen."
        case 1:
            return "Community solutions usually disagree on implementation style here. Capture the invariant first, then compare memory and readability tradeoffs."
        default:
            return "Useful discussion often clusters around \(topic.lowercased()) edge cases, especially duplicate values, empty inputs, and reset conditions."
        }
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

struct ProblemDetailCommunityHighlight: Identifiable {
    let title: String
    let body: String

    var id: String { title }
}

struct ProblemDetailSimilarQuestion: Identifiable {
    let title: String
    let subtitle: String

    var id: String { title }
}

private extension String {
    func strippingHTMLTags() -> String {
        replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
