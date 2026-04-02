import Foundation

actor LeetCodeAPI {
    static let shared = LeetCodeAPI()

    private let endpoint = URL(string: "https://leetcode.com/graphql")!
    private let baseURL = URL(string: "https://leetcode.com")!
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
        variables: sending [String: Any] = [:],
        responseType: T.Type
    ) async throws -> T {
        var request = authenticatedRequest(url: endpoint, referer: "https://leetcode.com")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
        difficulty: String? = nil,
        status: String? = nil,
        searchKeywords: String? = nil,
        tags: [String]? = nil
    ) async throws -> ProblemListResult {
        var filters: [String: Any] = [:]
        if let difficulty { filters["difficulty"] = difficulty }
        if let status { filters["status"] = status }
        if let searchKeywords, !searchKeywords.isEmpty { filters["searchKeywords"] = searchKeywords }
        if let tags, !tags.isEmpty { filters["tags"] = tags }

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

    func fetchContestRanking(username: String) async throws -> ContestRankingInfo? {
        let response = try await query(
            GraphQLQueries.userContestRankingInfo,
            variables: ["username": username],
            responseType: ContestRankingResponse.self
        )
        return response.userContestRanking
    }

    func fetchProfileCalendar(username: String, year: Int? = nil) async throws -> UserCalendar? {
        var variables: [String: Any] = ["username": username]
        if let year {
            variables["year"] = year
        }

        let response = try await query(
            GraphQLQueries.userProfileCalendar,
            variables: variables,
            responseType: UserProfileCalendarResponse.self
        )
        return response.matchedUser.userCalendar
    }

    func fetchSimilarQuestions(titleSlug: String) async throws -> [SimilarQuestion] {
        let response = try await query(
            GraphQLQueries.similarQuestions,
            variables: ["titleSlug": titleSlug],
            responseType: SimilarQuestionsResponse.self
        )
        return response.question.similarQuestionList
    }

    func fetchQuestionHints(titleSlug: String) async throws -> [String] {
        let response = try await query(
            GraphQLQueries.questionHints,
            variables: ["titleSlug": titleSlug],
            responseType: QuestionHintsResponse.self
        )
        return response.question.hints
    }

    func fetchOfficialSolution(titleSlug: String) async throws -> OfficialSolution? {
        let response = try await query(
            GraphQLQueries.officialSolution,
            variables: ["titleSlug": titleSlug],
            responseType: OfficialSolutionResponse.self
        )
        return response.question.solution
    }

    func fetchCommunitySolutions(
        questionSlug: String,
        skip: Int = 0,
        first: Int = 15,
        query searchQuery: String = "",
        orderBy: String = "hot",
        languageTags: [String] = [],
        topicTags: [String] = []
    ) async throws -> CommunitySolutionsResult {
        let response = try await query(
            GraphQLQueries.communitySolutions,
            variables: [
                "questionSlug": questionSlug,
                "skip": skip,
                "first": first,
                "query": searchQuery,
                "orderBy": orderBy,
                "languageTags": languageTags,
                "topicTags": topicTags
            ],
            responseType: CommunitySolutionsResponse.self
        )
        return response.questionSolutions
    }

    func fetchDiscussionArticles(
        orderBy: String? = nil,
        keywords: [String],
        tagSlugs: [String] = [],
        skip: Int = 0,
        first: Int = 10
    ) async throws -> DiscussionArticlesConnection {
        var variables: [String: Any] = [
            "keywords": keywords,
            "tagSlugs": tagSlugs,
            "skip": skip,
            "first": first
        ]
        if let orderBy {
            variables["orderBy"] = orderBy
        }

        let response = try await query(
            GraphQLQueries.discussionArticles,
            variables: variables,
            responseType: DiscussionArticlesResponse.self
        )
        return response.ugcArticleDiscussionArticles
    }

    func fetchDiscussionArticle(topicId: String) async throws -> DiscussionArticle {
        let response = try await query(
            GraphQLQueries.discussionArticleDetail,
            variables: ["topicId": topicId],
            responseType: DiscussionArticleDetailResponse.self
        )
        return response.ugcArticleDiscussionArticle
    }

    func fetchDiscussionTags() async throws -> [DiscussionTag] {
        let response = try await query(
            GraphQLQueries.discussionTags,
            responseType: DiscussionTagsResponse.self
        )
        return response.ugcArticleFollowedDiscussionTags
    }

    func fetchFavoriteLists() async throws -> FavoriteLists {
        try await query(
            GraphQLQueries.myFavoriteList,
            responseType: FavoriteLists.self
        )
    }

    func fetchFavoriteQuestions(
        favoriteSlug: String,
        limit: Int = 100,
        skip: Int = 0
    ) async throws -> FavoriteQuestionListResult {
        let response = try await query(
            GraphQLQueries.favoriteQuestionList,
            variables: [
                "favoriteSlug": favoriteSlug,
                "limit": limit,
                "skip": skip,
                "sortBy": [:],
                "filtersV2": [:]
            ],
            responseType: FavoriteQuestionListResponse.self
        )
        return response.favoriteQuestionList
    }

    func runCode(
        questionTitleSlug: String,
        questionId: String,
        programmingLanguage: String,
        code: String,
        testCases: String,
        submitCode: Bool
    ) async throws -> CodeExecutionHandle {
        let sanitizedSlug = questionTitleSlug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? questionTitleSlug
        let path = "/problems/\(sanitizedSlug)/\(submitCode ? "submit" : "interpret_solution")/"
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw APIError.noData
        }
        var request = authenticatedRequest(
            url: url,
            referer: "https://leetcode.com/problems/\(sanitizedSlug)/"
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = [
            "lang": programmingLanguage,
            "question_id": questionId,
            "typed_code": code
        ]
        if !submitCode {
            payload["data_input"] = testCases
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data = try await sendJSONRequest(request)
        if submitCode, let submissionId = parseIntValue(data["submission_id"]) {
            return .submission(id: submissionId)
        }

        if let interpretId = parseStringValue(data["interpret_id"]) {
            return .interpret(id: interpretId)
        }

        throw APIError.noData
    }

    func checkSubmission(id: String) async throws -> SubmissionCheckResult {
        let sanitizedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        guard let url = URL(string: "/submissions/detail/\(sanitizedId)/check/", relativeTo: baseURL)?.absoluteURL else {
            throw APIError.noData
        }
        let request = authenticatedRequest(url: url, referer: nil)
        let data = try await sendJSONRequest(request)
        let json = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(SubmissionCheckResult.self, from: json)
    }

    private func authenticatedRequest(url: URL, referer: String?) -> URLRequest {
        var request = URLRequest(url: url)
        if let referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
            request.setValue("https://leetcode.com", forHTTPHeaderField: "Origin")
        }

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

        return request
    }

    private func sendJSONRequest(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.httpError(statusCode: statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.noData
        }

        return json
    }

    private func parseIntValue(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let stringValue = value as? String {
            return Int(stringValue)
        }
        return nil
    }

    private func parseStringValue(_ value: Any?) -> String? {
        if let stringValue = value as? String {
            return stringValue
        }
        if let intValue = value as? Int {
            return String(intValue)
        }
        return nil
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

struct ProblemListResult: Codable {
    let total: Int
    let questions: [Problem]
}

struct Problem: Codable, Identifiable {
    var id: String { titleSlug }
    let titleSlug: String
    let title: String
    let difficulty: String
    let topicTags: [TopicTag]
    let acRate: Double
    let status: String?

    enum CodingKeys: String, CodingKey {
        case titleSlug, title, difficulty, topicTags, acRate, status
    }
}

struct TopicTag: Codable {
    let name: String
    let slug: String?
    let translatedName: String?
}

struct ProblemDetailResponse: Decodable {
    let question: ProblemDetail
}

struct ProblemDetail: Codable {
    let questionId: String?
    let frontendQuestionId: String?
    let title: String?
    let titleSlug: String?
    let content: String?
    let status: String?
    let isPaidOnly: Bool?
    let acRate: Double?
    let codeSnippets: [CodeSnippet]?
    let difficulty: String
    let topicTags: [TopicTag]
    let stats: String?
    let hints: [String]?
    let likes: Int
    let dislikes: Int
    let exampleTestcases: String?
    let exampleTestcaseList: [String]?
    let solution: OfficialSolution?
}

struct CodeSnippet: Codable {
    let lang: String
    let langSlug: String?
    let code: String
}

struct SubmissionListResponse: Decodable {
    let questionSubmissionList: SubmissionListResult
}

struct SubmissionListResult: Decodable {
    private enum CodingKeys: String, CodingKey {
        case submissions
    }

    let submissions: [Submission]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        submissions = try container.decodeIfPresent([Submission].self, forKey: .submissions) ?? []
    }
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
    let titleSlug: String?
    let cardImg: String?
    let startTime: Int
    let duration: Int
}

struct UserProfileResponse: Decodable {
    let matchedUser: UserProfile
}

struct UserProfile: Decodable {
    let username: String?
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
    let realName: String?
    let aboutMe: String?
    let userAvatar: String?
    let countryName: String?
    let company: String?
    let school: String?
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

struct ContestRankingResponse: Decodable {
    let userContestRanking: ContestRankingInfo?
}

struct ContestRankingInfo: Decodable {
    let attendedContestsCount: Int?
    let rating: Double?
    let globalRanking: Int?
    let totalParticipants: Int?
    let topPercentage: Double?
}

struct UserProfileCalendarResponse: Decodable {
    let matchedUser: CalendarUser
}

struct CalendarUser: Decodable {
    let userCalendar: UserCalendar?
}

struct UserCalendar: Decodable {
    let activeYears: [Int]
    let streak: Int
    let totalActiveDays: Int
    let submissionCalendar: String
}

struct SimilarQuestionsResponse: Decodable {
    let question: SimilarQuestionContainer
}

struct SimilarQuestionContainer: Decodable {
    let similarQuestionList: [SimilarQuestion]
}

struct SimilarQuestion: Decodable, Identifiable {
    var id: String { titleSlug }
    let difficulty: String
    let titleSlug: String
    let title: String
    let isPaidOnly: Bool?
}

struct QuestionHintsResponse: Decodable {
    let question: QuestionHintsContainer
}

struct QuestionHintsContainer: Decodable {
    let hints: [String]
}

struct OfficialSolutionResponse: Decodable {
    let question: OfficialSolutionContainer
}

struct OfficialSolutionContainer: Decodable {
    let solution: OfficialSolution?
}

struct OfficialSolution: Codable {
    let id: String
    let title: String?
    let content: String?
    let paidOnly: Bool?
    let hasVideoSolution: Bool?
    let paidOnlyVideo: Bool?
    let canSeeDetail: Bool?
}

struct CommunitySolutionsResponse: Decodable {
    let questionSolutions: CommunitySolutionsResult
}

struct CommunitySolutionsResult: Decodable {
    let hasDirectResults: Bool
    let totalNum: Int
    let solutions: [CommunitySolution]
}

struct CommunitySolution: Decodable, Identifiable {
    let id: String
    let title: String
    let commentCount: Int?
    let topLevelCommentCount: Int?
    let viewCount: Int?
    let solutionTags: [DiscussionArticleTag]
    let post: CommunityPost
}

struct CommunityPost: Decodable {
    let id: String
    let voteCount: Int?
    let creationDate: Int?
    let author: CommunityAuthor?
}

struct CommunityAuthor: Decodable {
    let username: String
    let profile: CommunityAuthorProfile?
}

struct CommunityAuthorProfile: Decodable {
    let userAvatar: String?
    let realName: String?
    let reputation: Int?
}

struct DiscussionArticlesResponse: Decodable {
    let ugcArticleDiscussionArticles: DiscussionArticlesConnection
}

struct DiscussionArticlesConnection: Decodable {
    let totalNum: Int
    let pageInfo: DiscussionPageInfo
    let edges: [DiscussionArticleEdge]
}

struct DiscussionPageInfo: Decodable {
    let hasNextPage: Bool
}

struct DiscussionArticleEdge: Decodable {
    let node: DiscussionArticle
}

struct DiscussionArticleDetailResponse: Decodable {
    let ugcArticleDiscussionArticle: DiscussionArticle
}

struct DiscussionArticle: Decodable, Identifiable {
    var id: String { uuid }
    let uuid: String
    let title: String
    let slug: String
    let summary: String?
    let content: String?
    let createdAt: String?
    let updatedAt: String?
    let topicId: String?
    let hitCount: Int?
    let author: DiscussionArticleAuthor?
    let tags: [DiscussionArticleTag]
    let topic: DiscussionTopic?
}

struct DiscussionArticleAuthor: Decodable {
    let realName: String?
    let userAvatar: String?
    let userName: String?
}

struct DiscussionArticleTag: Decodable, Identifiable {
    var id: String { slug }
    let name: String
    let slug: String
    let tagType: String?
}

struct DiscussionTopic: Decodable {
    let id: String
    let topLevelCommentCount: Int?
}

struct DiscussionTagsResponse: Decodable {
    let ugcArticleFollowedDiscussionTags: [DiscussionTag]
}

struct DiscussionTag: Decodable, Identifiable {
    let id: String
    let name: String
    let slug: String
}

struct FavoriteLists: Decodable {
    let myCreatedFavoriteList: FavoriteListCollection
    let myCollectedFavoriteList: FavoriteListCollection
}

struct FavoriteListCollection: Decodable {
    let favorites: [FavoriteList]
    let hasMore: Bool
    let totalLength: Int
}

struct FavoriteList: Decodable, Identifiable {
    var id: String { slug }
    let name: String
    let slug: String
    let favoriteType: String?
    let coverEmoji: String?
    let coverBackgroundColor: String?
    let hasCurrentQuestion: Bool?
    let isPublicFavorite: Bool?
    let lastQuestionAddedAt: Int?
}

struct FavoriteQuestionListResponse: Decodable {
    let favoriteQuestionList: FavoriteQuestionListResult
}

struct FavoriteQuestionListResult: Decodable {
    let questions: [FavoriteQuestion]
    let totalLength: Int
    let hasMore: Bool
}

struct FavoriteQuestion: Decodable, Identifiable {
    var id: String { titleSlug }
    let difficulty: String
    let paidOnly: Bool?
    let questionFrontendId: String?
    let status: String?
    let title: String
    let titleSlug: String
    let isInMyFavorites: Bool?
    let frequency: Double?
    let acRate: Double
    let topicTags: [FavoriteTopicTag]
}

struct FavoriteTopicTag: Decodable, Identifiable {
    var id: String { slug }
    let name: String
    let slug: String
}

enum CodeExecutionHandle {
    case interpret(id: String)
    case submission(id: Int)
}

struct SubmissionCheckResult: Decodable {
    let state: String?
    let statusCode: Int?
    let statusMsg: String?
    let runSuccess: Bool?
    let runtime: String?
    let memory: String?
    let totalCorrect: Int?
    let totalTestcases: Int?
    let compareResult: String?
    let codeAnswer: [String]?
    let expectedCodeAnswer: [String]?
    let inputFormatted: String?

    private enum CodingKeys: String, CodingKey {
        case state
        case statusCode = "status_code"
        case statusMsg = "status_msg"
        case runSuccess = "run_success"
        case runtime
        case memory
        case totalCorrect = "total_correct"
        case totalTestcases = "total_testcases"
        case compareResult = "compare_result"
        case codeAnswer = "code_answer"
        case expectedCodeAnswer = "expected_code_answer"
        case inputFormatted = "input_formatted"
    }
}
