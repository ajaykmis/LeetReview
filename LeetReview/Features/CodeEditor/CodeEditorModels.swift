import Foundation

struct CodeEditorProblemSnapshot: Identifiable, Sendable {
    var id: String { titleSlug }

    let questionId: String
    let title: String
    let titleSlug: String
    let difficulty: String
    let summary: String
    let starterCodes: [CodeEditorStarterCode]
    let initialTestCases: [CodeEditorTestCase]

    var defaultLanguageSlug: String {
        starterCodes.first?.languageSlug ?? "swift"
    }

    static let sample = CodeEditorProblemSnapshot(
        questionId: "1",
        title: "Two Sum",
        titleSlug: "two-sum",
        difficulty: "Easy",
        summary: """
        Return the indices of the two numbers such that they add up to the target.
        You may assume each input has exactly one solution, and you may not use the same element twice.
        """,
        starterCodes: [
            CodeEditorStarterCode(
                languageName: "Swift",
                languageSlug: "swift",
                code: """
                class Solution {
                    func twoSum(_ nums: [Int], _ target: Int) -> [Int] {
                        // TODO: implement
                        return []
                    }
                }
                """
            ),
            CodeEditorStarterCode(
                languageName: "Python",
                languageSlug: "python3",
                code: """
                class Solution:
                    def twoSum(self, nums: list[int], target: int) -> list[int]:
                        # TODO: implement
                        return []
                """
            ),
            CodeEditorStarterCode(
                languageName: "JavaScript",
                languageSlug: "javascript",
                code: """
                /**
                 * @param {number[]} nums
                 * @param {number} target
                 * @return {number[]}
                 */
                var twoSum = function(nums, target) {
                    // TODO: implement
                    return [];
                };
                """
            )
        ],
        initialTestCases: [
            CodeEditorTestCase(
                label: "Case 1",
                input: "nums = [2,7,11,15], target = 9",
                expectedOutput: "[0,1]"
            ),
            CodeEditorTestCase(
                label: "Case 2",
                input: "nums = [3,2,4], target = 6",
                expectedOutput: "[1,2]"
            )
        ]
    )
}

struct CodeEditorStarterCode: Identifiable, Hashable, Sendable {
    var id: String { languageSlug }

    let languageName: String
    let languageSlug: String
    let code: String
}

struct CodeEditorTestCase: Identifiable, Hashable, Sendable {
    let id: UUID
    var label: String
    var input: String
    var expectedOutput: String

    init(
        id: UUID = UUID(),
        label: String,
        input: String,
        expectedOutput: String = ""
    ) {
        self.id = id
        self.label = label
        self.input = input
        self.expectedOutput = expectedOutput
    }
}

struct CodeExecutionRequest: Sendable {
    let questionId: String
    let titleSlug: String
    let languageSlug: String
    let code: String
    let testCases: [CodeEditorTestCase]
}

struct TestCaseResult: Identifiable, Sendable {
    let id = UUID()
    let index: Int
    let input: String
    let expectedOutput: String
    let actualOutput: String
    let stdOutput: String
    let passed: Bool
}

struct CodeExecutionResult: Sendable {
    let status: CodeExecutionStatus
    let statusMessage: String
    let completedCaseCount: Int
    let totalCaseCount: Int
    let testCaseResults: [TestCaseResult]
    let compileError: String?
    let runtimeError: String?
    let runtime: String?
    let memory: String?
}

enum CodeExecutionStatus: String, Sendable {
    case passed = "Passed"
    case failed = "Failed"
    case blocked = "Blocked"
}

struct CodePerformanceSnapshot: Hashable, Sendable {
    let runtime: String
    let memory: String
    let runtimePercentile: Double?
    let memoryPercentile: Double?
}

struct CodeSubmissionResult: Sendable {
    let status: CodeSubmissionStatus
    let summary: String
    let passedCaseCount: Int
    let totalCaseCount: Int
    let performance: CodePerformanceSnapshot?
    let lastTestcaseInput: String?
    let lastExpectedOutput: String?
    let lastCodeOutput: String?
    let compileError: String?
    let runtimeError: String?
}

enum CodeSubmissionStatus: String, Sendable {
    case accepted = "Accepted"
    case wrongAnswer = "Wrong Answer"
    case runtimeError = "Runtime Error"
    case compileError = "Compile Error"
    case loginRequired = "Login Required"
}

extension CodeEditorProblemSnapshot {
    init?(detail: ProblemDetail, fallbackTitle: String) {
        let resolvedQuestionID = detail.questionId ?? detail.frontendQuestionId
        let resolvedTitleSlug = detail.titleSlug
        let starterCodes = detail.codeSnippets?
            .compactMap { snippet -> CodeEditorStarterCode? in
                guard let languageSlug = snippet.langSlug, !languageSlug.isEmpty else {
                    return nil
                }
                return CodeEditorStarterCode(
                    languageName: snippet.lang,
                    languageSlug: languageSlug,
                    code: snippet.code
                )
            } ?? []

        guard
            let questionId = resolvedQuestionID,
            let titleSlug = resolvedTitleSlug,
            !starterCodes.isEmpty
        else {
            return nil
        }

        let summary = detail.content?
            .removingHTMLTags()
            .collapsingWhitespace()
            ?? "Open the editor to work through this problem."

        let initialCases = detail.makeEditorTestCases()

        self.init(
            questionId: questionId,
            title: detail.title ?? fallbackTitle,
            titleSlug: titleSlug,
            difficulty: detail.difficulty,
            summary: summary,
            starterCodes: starterCodes,
            initialTestCases: initialCases.isEmpty
                ? [CodeEditorTestCase(label: "Case 1", input: "", expectedOutput: "")]
                : initialCases
        )
    }
}

private extension ProblemDetail {
    func makeEditorTestCases() -> [CodeEditorTestCase] {
        let expectedOutputs = parseExpectedOutputsFromHTML()

        if let examples = exampleTestcaseList, !examples.isEmpty {
            return examples.enumerated().map { index, input in
                CodeEditorTestCase(
                    label: "Case \(index + 1)",
                    input: input,
                    expectedOutput: index < expectedOutputs.count ? expectedOutputs[index] : ""
                )
            }
        }

        if let rawExamples = exampleTestcases?
            .components(separatedBy: .newlines)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty }),
           !rawExamples.isEmpty {
            return rawExamples.enumerated().map { index, input in
                CodeEditorTestCase(
                    label: "Case \(index + 1)",
                    input: input,
                    expectedOutput: index < expectedOutputs.count ? expectedOutputs[index] : ""
                )
            }
        }

        return []
    }

    func parseExpectedOutputsFromHTML() -> [String] {
        guard let content = content else { return [] }
        let pattern = #"<strong>Output:?\s*</strong>\s*(.+?)(?:\s*<|\n)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsContent = content as NSString
        return regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { return nil }
            return nsContent.substring(with: range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
    }
}

private extension String {
    func removingHTMLTags() -> String {
        replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func collapsingWhitespace() -> String {
        replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
