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
        problemsetQuestionList: questionList(categorySlug: $categorySlug, limit: $limit, skip: $skip, filters: $filters) {
            total: totalNum
            questions: data {
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
    query questionData($titleSlug: String!) {
        question(titleSlug: $titleSlug) {
            questionId
            frontendQuestionId: questionFrontendId
            title
            titleSlug
            content
            status
            isPaidOnly
            acRate
            difficulty
            likes
            dislikes
            exampleTestcases
            categoryTitle
            topicTags {
                name
                slug
                translatedName
            }
            stats
            hints
            solution {
                id
                canSeeDetail
                paidOnly
                hasVideoSolution
                paidOnlyVideo
            }
            codeSnippets {
                lang
                langSlug
                code
            }
            exampleTestcaseList
        }
    }
    """

    static let similarQuestions = """
    query SimilarQuestions($titleSlug: String!) {
        question(titleSlug: $titleSlug) {
            similarQuestionList {
                difficulty
                titleSlug
                title
                translatedTitle
                isPaidOnly
            }
        }
    }
    """

    static let officialSolution = """
    query officialSolution($titleSlug: String!) {
        question(titleSlug: $titleSlug) {
            solution {
                id
                title
                content
                paidOnly
                hasVideoSolution
                paidOnlyVideo
                canSeeDetail
            }
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
            titleSlug
            cardImg
            startTime
            duration
        }
    }
    """

    static let userProfile = """
    query userProfile($username: String!) {
        matchedUser(username: $username) {
            username
            submitStats {
                acSubmissionNum { difficulty count }
            }
            profile {
                ranking
                reputation
                realName
                aboutMe
                userAvatar
                countryName
                company
                school
            }
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

    static let userContestRankingInfo = """
    query userContestRankingInfo($username: String!) {
        userContestRanking(username: $username) {
            attendedContestsCount
            rating
            globalRanking
            totalParticipants
            topPercentage
        }
        userContestRankingHistory(username: $username) {
            attended
            problemsSolved
            totalProblems
            rating
            ranking
            contest { title startTime }
        }
    }
    """

    static let userProfileCalendar = """
    query userProfileCalendar($username: String!, $year: Int) {
        matchedUser(username: $username) {
            userCalendar(year: $year) {
                activeYears
                streak
                totalActiveDays
                submissionCalendar
            }
        }
    }
    """

    static let questionHints = """
    query questionHints($titleSlug: String!) {
        question(titleSlug: $titleSlug) {
            hints
        }
    }
    """

    static let communitySolutions = """
    query communitySolutions($questionSlug: String!, $skip: Int!, $first: Int!, $query: String, $orderBy: TopicSortingOption, $languageTags: [String!], $topicTags: [String!]) {
        questionSolutions(
            filters: {
                questionSlug: $questionSlug,
                skip: $skip,
                first: $first,
                query: $query,
                orderBy: $orderBy,
                languageTags: $languageTags,
                topicTags: $topicTags
            }
        ) {
            hasDirectResults
            totalNum
            solutions {
                id
                title
                commentCount
                topLevelCommentCount
                viewCount
                solutionTags { name slug }
                post {
                    id
                    voteCount
                    creationDate
                    author {
                        username
                        profile { userAvatar realName reputation }
                    }
                }
            }
        }
    }
    """

    static let discussionArticles = """
    query discussPostItems($orderBy: ArticleOrderByEnum, $keywords: [String]!, $tagSlugs: [String!], $skip: Int, $first: Int) {
        ugcArticleDiscussionArticles(
            orderBy: $orderBy,
            keywords: $keywords,
            tagSlugs: $tagSlugs,
            skip: $skip,
            first: $first
        ) {
            totalNum
            pageInfo { hasNextPage }
            edges {
                node {
                    uuid
                    title
                    slug
                    summary
                    createdAt
                    updatedAt
                    topicId
                    hitCount
                    author {
                        realName
                        userAvatar
                        userName
                    }
                    tags { name slug tagType }
                    topic { id topLevelCommentCount }
                }
            }
        }
    }
    """

    static let discussionArticleDetail = """
    query discussPostDetail($topicId: ID!) {
        ugcArticleDiscussionArticle(topicId: $topicId) {
            uuid
            title
            slug
            summary
            content
            createdAt
            updatedAt
            topicId
            hitCount
            author {
                realName
                userAvatar
                userName
            }
            tags { name slug tagType }
            topic { id topLevelCommentCount }
        }
    }
    """

    static let discussionTags = """
    query discussFollowedTopics {
        ugcArticleFollowedDiscussionTags {
            id
            name
            slug
        }
    }
    """

    static let myFavoriteList = """
    query myFavoriteList {
        myCreatedFavoriteList {
            favorites {
                name
                slug
                favoriteType
                coverEmoji
                coverBackgroundColor
                hasCurrentQuestion
                isPublicFavorite
                lastQuestionAddedAt
            }
            hasMore
            totalLength
        }
        myCollectedFavoriteList {
            favorites {
                name
                slug
                favoriteType
                coverEmoji
                coverBackgroundColor
                hasCurrentQuestion
                isPublicFavorite
                lastQuestionAddedAt
            }
            hasMore
            totalLength
        }
    }
    """

    static let favoriteQuestionList = """
    query favoriteQuestionList($favoriteSlug: String!, $filtersV2: QuestionFilterInput, $sortBy: QuestionSortByInput, $limit: Int, $skip: Int, $version: String = "v2") {
        favoriteQuestionList(
            favoriteSlug: $favoriteSlug,
            filtersV2: $filtersV2,
            sortBy: $sortBy,
            limit: $limit,
            skip: $skip,
            version: $version
        ) {
            questions {
                difficulty
                paidOnly
                questionFrontendId
                status
                title
                titleSlug
                isInMyFavorites
                frequency
                acRate
                topicTags { name slug }
            }
            totalLength
            hasMore
        }
    }
    """
}
