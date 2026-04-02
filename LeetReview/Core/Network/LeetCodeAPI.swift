import Foundation

actor LeetCodeAPI {
    static let shared = LeetCodeAPI()

    private let endpoint = URL(string: "https://leetcode.com/graphql")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Core GraphQL

    func query<T: Decodable>(
        _ queryString: String,
        variables: [String: Any] = [:],
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://leetcode.com", forHTTPHeaderField: "Referer")
        request.setValue("https://leetcode.com", forHTTPHeaderField: "Origin")

        if let csrfToken = AuthManager.getCSRFToken() {
            request.setValue(csrfToken, forHTTPHeaderField: "x-csrftoken")
        }

        if let sessionCookie = AuthManager.getSessionCookie() {
            let csrfToken = AuthManager.getCSRFToken() ?? ""
            request.setValue(
                "LEETCODE_SESSION=\(sessionCookie); csrftoken=\(csrfToken)",
                forHTTPHeaderField: "Cookie"
            )
        }

        let body: [String: Any] = [
            "query": queryString,
            "variables": variables
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.httpError(statusCode: statusCode)
        }

        let decoded = try JSONDecoder().decode(GraphQLResponse<T>.self, from: data)

        if let errors = decoded.errors, !errors.isEmpty {
            throw APIError.graphQL(errors.map(\.message))
        }

        guard let result = decoded.data else {
            throw APIError.noData
        }

        return result
    }

    // MARK: - Auth

    func checkLoginStatus() async throws -> UserStatus {
        let response = try await query(
            GraphQLQueries.userStatus,
            responseType: UserStatusResponse.self
        )
        return response.userStatus
    }

    // MARK: - Problems

    func fetchProblemList(
        limit: Int = 50,
        skip: Int = 0,
        filters: [String: Any] = [:]
    ) async throws -> ProblemListResult {
        let variables: [String: Any] = [
            "categorySlug": "",
            "limit": limit,
            "skip": skip,
            "filters": filters
        ]
        let response = try await query(
            GraphQLQueries.problemsetQuestionList,
            variables: variables,
            responseType: ProblemListResponse.self
        )
        return response.problemsetQuestionList
    }

    func fetchProblemDetail(titleSlug: String) async throws -> ProblemDetail {
        let response = try await query(
            GraphQLQueries.questionContent,
            variables: ["titleSlug": titleSlug],
            responseType: ProblemDetailResponse.self
        )
        return response.question
    }

    // MARK: - Submissions

    func fetchSubmissions(
        questionSlug: String,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [Submission] {
        let variables: [String: Any] = [
            "questionSlug": questionSlug,
            "limit": limit,
            "offset": offset
        ]
        let response = try await query(
            GraphQLQueries.submissionList,
            variables: variables,
            responseType: SubmissionListResponse.self
        )
        return response.questionSubmissionList.submissions
    }

    func fetchSubmissionDetail(submissionId: Int) async throws -> SubmissionDetail {
        let response = try await query(
            GraphQLQueries.submissionDetails,
            variables: ["submissionId": submissionId],
            responseType: SubmissionDetailResponse.self
        )
        return response.submissionDetails
    }

    // MARK: - Dashboard

    func fetchDailyChallenge() async throws -> DailyChallenge {
        let response = try await query(
            GraphQLQueries.questionOfToday,
            responseType: DailyChallengeResponse.self
        )
        return response.activeDailyCodingChallengeQuestion
    }

    func fetchUpcomingContests() async throws -> [Contest] {
        let response = try await query(
            GraphQLQueries.upcomingContests,
            responseType: UpcomingContestsResponse.self
        )
        return response.upcomingContests
    }

    // MARK: - Profile

    func fetchUserProfile(username: String) async throws -> UserProfile {
        let response = try await query(
            GraphQLQueries.userProfile,
            variables: ["username": username],
            responseType: UserProfileResponse.self
        )
        return response.matchedUser
    }

    func fetchRecentSubmissions(
        username: String,
        limit: Int = 15
    ) async throws -> [RecentSubmission] {
        let response = try await query(
            GraphQLQueries.recentAcSubmissions,
            variables: ["username": username, "limit": limit],
            responseType: RecentSubmissionsResponse.self
        )
        return response.recentAcSubmissionList
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case httpError(statusCode: Int)
    case graphQL([String])
    case noData

    var errorDescription: String? {
        switch self {
        case .httpError(let code):
            "HTTP error: \(code)"
        case .graphQL(let messages):
            "GraphQL errors: \(messages.joined(separator: ", "))"
        case .noData:
            "No data in response"
        }
    }
}

// MARK: - GraphQL Envelope

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable {
    let message: String
}

// MARK: - Response Models

struct UserStatusResponse: Decodable {
    let userStatus: UserStatus
}

struct UserStatus: Decodable {
    let username: String?
    let isSignedIn: Bool
}

struct ProblemListResponse: Decodable {
    let problemsetQuestionList: ProblemListResult
}

struct ProblemListResult: Decodable {
    let total: Int
    let questions: [Problem]
}

struct Problem: Decodable, Identifiable {
    var id: String { titleSlug }
    let titleSlug: String
    let title: String
    let difficulty: String
    let topicTags: [TopicTag]
    let acRate: Double
    let status: String?
}

struct TopicTag: Decodable {
    let name: String
}

struct ProblemDetailResponse: Decodable {
    let question: ProblemDetail
}

struct ProblemDetail: Decodable {
    let content: String?
    let codeSnippets: [CodeSnippet]?
    let difficulty: String
    let topicTags: [TopicTag]
    let stats: String?
    let likes: Int
    let dislikes: Int
}

struct CodeSnippet: Decodable {
    let lang: String
    let code: String
}

struct SubmissionListResponse: Decodable {
    let questionSubmissionList: SubmissionListResult
}

struct SubmissionListResult: Decodable {
    let submissions: [Submission]
}

struct Submission: Decodable, Identifiable {
    let id: String
    let title: String?
    let statusDisplay: String
    let lang: String
    let timestamp: String
}

struct SubmissionDetailResponse: Decodable {
    let submissionDetails: SubmissionDetail
}

struct SubmissionDetail: Decodable {
    let code: String
    let lang: String
    let runtime: String?
    let memory: String?
    let timestamp: String
    let statusDisplay: String
}

struct DailyChallengeResponse: Decodable {
    let activeDailyCodingChallengeQuestion: DailyChallenge
}

struct DailyChallenge: Decodable {
    let date: String
    let question: DailyChallengeQuestion
}

struct DailyChallengeQuestion: Decodable {
    let titleSlug: String
    let title: String
    let difficulty: String
}

struct UpcomingContestsResponse: Decodable {
    let upcomingContests: [Contest]
}

struct Contest: Decodable, Identifiable {
    var id: String { title }
    let title: String
    let startTime: Int
    let duration: Int
}

struct UserProfileResponse: Decodable {
    let matchedUser: UserProfile
}

struct UserProfile: Decodable {
    let submitStats: SubmitStats
    let profile: ProfileInfo
}

struct SubmitStats: Decodable {
    let acSubmissionNum: [DifficultyCount]
}

struct DifficultyCount: Decodable {
    let difficulty: String
    let count: Int
}

struct ProfileInfo: Decodable {
    let ranking: Int
    let reputation: Int
}

struct RecentSubmissionsResponse: Decodable {
    let recentAcSubmissionList: [RecentSubmission]
}

struct RecentSubmission: Decodable, Identifiable {
    var id: String { "\(titleSlug)-\(timestamp)" }
    let title: String
    let titleSlug: String
    let timestamp: String
    let lang: String
    let statusDisplay: String
}
