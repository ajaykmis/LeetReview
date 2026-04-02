import Foundation

enum GraphQLQueries {
    static let userStatus = """
    query {
        userStatus {
            username
            isSignedIn
        }
    }
    """

    static let problemsetQuestionList = """
    query problemsetQuestionList($categorySlug: String, $limit: Int, $skip: Int, $filters: QuestionListFilterInput) {
        problemsetQuestionList(categorySlug: $categorySlug, limit: $limit, skip: $skip, filters: $filters) {
            total
            questions {
                titleSlug
                title
                difficulty
                topicTags { name }
                acRate
                status
            }
        }
    }
    """

    static let questionContent = """
    query questionContent($titleSlug: String!) {
        question(titleSlug: $titleSlug) {
            content
            codeSnippets { lang code }
            difficulty
            topicTags { name }
            stats
            likes
            dislikes
        }
    }
    """

    static let submissionList = """
    query submissionList($questionSlug: String!, $limit: Int, $offset: Int) {
        questionSubmissionList(questionSlug: $questionSlug, limit: $limit, offset: $offset) {
            submissions {
                id
                title
                statusDisplay
                lang
                timestamp
            }
        }
    }
    """

    static let submissionDetails = """
    query submissionDetails($submissionId: Int!) {
        submissionDetails(submissionId: $submissionId) {
            code
            lang
            runtime
            memory
            timestamp
            statusDisplay
        }
    }
    """

    static let questionOfToday = """
    query questionOfToday {
        activeDailyCodingChallengeQuestion {
            date
            question {
                titleSlug
                title
                difficulty
            }
        }
    }
    """

    static let upcomingContests = """
    query upcomingContests {
        upcomingContests {
            title
            startTime
            duration
        }
    }
    """

    static let userProfile = """
    query userProfile($username: String!) {
        matchedUser(username: $username) {
            submitStats {
                acSubmissionNum { difficulty count }
            }
            profile { ranking reputation }
        }
    }
    """

    static let recentAcSubmissions = """
    query recentAcSubmissions($username: String!, $limit: Int!) {
        recentAcSubmissionList(username: $username, limit: $limit) {
            title
            titleSlug
            timestamp
            lang
            statusDisplay
        }
    }
    """
}
