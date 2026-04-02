# LeetReview — SwiftUI Rewrite of CoderGym

## Overview

Clean SwiftUI rewrite of CoderGym (Flutter) with feature parity. Native iOS app for reviewing LeetCode problems, viewing your submissions, and practicing with spaced repetition.

MIT licensed fork of CoderGym's concept. Visual style matches CoderGym's dark theme.

## Target

- iOS 17+, Swift 6, SwiftUI
- Xcode 26+
- Minimal dependencies: KeychainAccess, Highlightr (syntax highlighting)
- Architecture: MVVM + Swift Concurrency (async/await)

## LeetCode API

All data comes from LeetCode's GraphQL endpoint (`https://leetcode.com/graphql`).
Auth is cookie-based (LEETCODE_SESSION + csrftoken from webview login).

### Key Queries

```graphql
# Check login status
query { userStatus { username isSignedIn } }

# Problem list with filters
query problemsetQuestionList($categorySlug: String, $limit: Int, $skip: Int, $filters: QuestionListFilterInput) {
  problemsetQuestionList(categorySlug: $categorySlug, limit: $limit, skip: $skip, filters: $filters) {
    total
    questions { titleSlug title difficulty topicTags { name } acRate status }
  }
}

# Problem detail
query questionContent($titleSlug: String!) {
  question(titleSlug: $titleSlug) {
    content codeSnippets { lang code } difficulty topicTags { name } stats likes dislikes
  }
}

# User's submissions for a problem
query submissionList($questionSlug: String!, $limit: Int, $offset: Int) {
  questionSubmissionList(questionSlug: $questionSlug, limit: $limit, offset: $offset) {
    submissions { id title statusDisplay lang timestamp }
  }
}

# Actual submitted code
query submissionDetails($submissionId: Int!) {
  submissionDetails(submissionId: $submissionId) { code lang runtime memory timestamp statusDisplay }
}

# Daily challenge
query questionOfToday {
  activeDailyCodingChallengeQuestion { date question { titleSlug title difficulty } }
}

# Upcoming contests
query upcomingContests { upcomingContests { title startTime duration } }

# User profile stats
query userProfile($username: String!) {
  matchedUser(username: $username) {
    submitStats { acSubmissionNum { difficulty count } }
    profile { ranking reputation }
  }
}

# User's recent AC submissions
query recentAcSubmissions($username: String!, $limit: Int!) {
  recentAcSubmissionList(username: $username, limit: $limit) {
    title titleSlug timestamp lang statusDisplay
  }
}
```

## Feature Modules (matching CoderGym)

### 1. Auth
- WKWebView-based login (loads leetcode.com/accounts/login)
- Extract LEETCODE_SESSION + csrftoken cookies on successful login
- Store in Keychain via KeychainAccess
- "Login with username only" mode for read-only features (public profile data)
- Logout: clear cookies + keychain

### 2. Dashboard (Home Tab)
- Daily coding challenge card (tap → problem detail)
- Upcoming contests list with countdown timers
- Recent activity summary
- Quick stats (problems solved by difficulty)

### 3. Problems (Browse Tab)
- Full problem list with infinite scroll pagination
- Filter by: difficulty (Easy/Medium/Hard), status (Todo/Solved/Attempted), tags
- Search by title or number
- Each row: title, difficulty badge, acceptance rate, solved status
- Tap → Problem Detail screen

### 4. Problem Detail
- Problem statement rendered from HTML (use AttributedString or WKWebView)
- Difficulty badge, tags, acceptance rate, likes/dislikes
- "My Submissions" section: list of your submissions with status, language, runtime
- Tap submission → view your code with syntax highlighting
- "Discussions" tab: community solutions (stretch goal)

### 5. Code Viewer (not full editor for v1)
- Syntax-highlighted code display (Highlightr)
- Language label
- Runtime + memory stats
- Copy to clipboard
- Scroll through multiple submissions

### 6. Profile Tab
- User stats: problems solved by difficulty (Easy/Medium/Hard)
- Submission calendar/heatmap (stretch goal)
- Recent accepted submissions list
- Ranking, reputation

### 7. Settings
- Theme toggle (dark is default, match CoderGym's dark palette)
- Clear cache
- Logout
- About / licenses

### 8. Review Mode (NEW — not in CoderGym)
- "Review" tab: spaced repetition for solved problems
- Shows problem title + difficulty → tap to reveal your solution
- Rate recall: Again / Hard / Good / Easy (SM-2 algorithm)
- Stores review state in SwiftData
- URL scheme `leetreview://problem/{slug}` for Anki card links

## Visual Design (match CoderGym)

- Dark theme primary: #1E1E2E (background), #2D2D3F (cards), #CDD6F4 (text)
- Accent: #89B4FA (blue), #A6E3A1 (green/easy), #F9E2AF (yellow/medium), #F38BA8 (red/hard)
- Font: System (SF Pro) — matches iOS native
- Bottom tab bar: Dashboard, Problems, Review, Profile, Settings
- Card-based layouts with rounded corners (16pt radius)
- Subtle shadows on cards

## Project Structure

```
LeetReview/
├── App/
│   ├── LeetReviewApp.swift          # @main, tab-based navigation
│   └── ContentView.swift            # Auth gate → TabView or LoginView
├── Core/
│   ├── Network/
│   │   ├── LeetCodeAPI.swift        # GraphQL client, cookie-based auth
│   │   └── GraphQLQueries.swift     # All query strings
│   ├── Auth/
│   │   ├── AuthManager.swift        # Session state, keychain ops
│   │   └── LoginWebView.swift       # WKWebView for LC login
│   ├── Storage/
│   │   ├── CacheManager.swift       # Disk cache for problems/solutions
│   │   └── ReviewStore.swift        # SwiftData model for spaced repetition
│   └── Theme/
│       └── Theme.swift              # Colors, fonts, spacing constants
├── Features/
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── DailyChallenge.swift
│   │   └── DashboardViewModel.swift
│   ├── Problems/
│   │   ├── ProblemListView.swift
│   │   ├── ProblemFilterView.swift
│   │   └── ProblemListViewModel.swift
│   ├── ProblemDetail/
│   │   ├── ProblemDetailView.swift
│   │   ├── SubmissionListView.swift
│   │   ├── CodeViewerView.swift
│   │   └── ProblemDetailViewModel.swift
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   └── ProfileViewModel.swift
│   ├── Review/
│   │   ├── ReviewSessionView.swift
│   │   ├── ReviewCardView.swift
│   │   └── ReviewViewModel.swift
│   └── Settings/
│       └── SettingsView.swift
└── Shared/
    ├── Components/
    │   ├── DifficultyBadge.swift
    │   ├── StatCard.swift
    │   └── CodeBlock.swift
    └── Extensions/
        ├── Color+Theme.swift
        └── Date+Relative.swift
```

## Stages (for Claude CLI agent pipeline)

### Stage 1: Project scaffold + Auth
- Create Xcode project
- Set up project structure (all directories)
- Implement LeetCodeAPI.swift (GraphQL client with cookie auth)
- Implement AuthManager.swift + LoginWebView.swift
- ContentView: if logged in → TabView, else → LoginView
- Theme.swift with CoderGym dark palette
- **Test**: Login flow works, session persists across app restart

### Stage 2: Dashboard + Problem List
- DashboardView: daily challenge, upcoming contests, quick stats
- ProblemListView: paginated list with search + filters
- DifficultyBadge, StatCard shared components
- **Test**: Problems load, filters work, daily challenge shows

### Stage 3: Problem Detail + Code Viewer
- ProblemDetailView: statement, tags, stats
- SubmissionListView: user's submissions for the problem
- CodeViewerView: syntax-highlighted code (Highlightr)
- **Test**: Can navigate from list → detail → view submitted code

### Stage 4: Profile + Settings
- ProfileView: solve stats, recent AC submissions
- SettingsView: logout, clear cache, theme toggle
- **Test**: Profile data loads, logout works

### Stage 5: Review Mode + Polish
- ReviewSessionView: spaced repetition flashcards
- ReviewStore (SwiftData): track review intervals
- URL scheme handler for `leetreview://problem/{slug}`
- App icon, launch screen
- Offline caching
- **Test**: Review flow works, URL scheme opens correct problem

## Agent Pipeline (per stage)

```bash
# Builder: implement the stage
claude code --project ~/Projects/LeetReview \
  "You are the BUILDER. Implement Stage N. Create branch stage-N/name. Write all code. Run xcodebuild to verify compilation. Commit and push."

# Evaluator: validate
claude code --project ~/Projects/LeetReview \
  "You are the EVALUATOR. Checkout stage-N/name. Run xcodebuild clean build. Run any tests. Verify no warnings. Report issues."

# Reviewer: code review
claude code --project ~/Projects/LeetReview \
  "You are the REVIEWER. Review the diff on stage-N/name vs main. Check Swift best practices, error handling, memory management, API edge cases. Approve or list changes needed."

# Builder: merge
claude code --project ~/Projects/LeetReview \
  "You are the BUILDER. Address any review feedback, then merge stage-N/name to main. Push."
```

## Dependencies

Add via Swift Package Manager:
- `KeychainAccess` — https://github.com/kishikawakatsumi/KeychainAccess
- `Highlightr` — https://github.com/raspu/Highlightr

No other third-party dependencies. Keep it lean.
