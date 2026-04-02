import Foundation

protocol CodeEditorServicing: Sendable {
    func runCode(_ request: CodeExecutionRequest) async throws -> CodeExecutionResult
    func submitCode(_ request: CodeExecutionRequest) async throws -> CodeSubmissionResult
}

struct LiveCodeEditorService: CodeEditorServicing {
    func runCode(_ request: CodeExecutionRequest) async throws -> CodeExecutionResult {
        guard AuthManager.hasSessionCredentials() else {
            return CodeExecutionResult(
                status: .blocked,
                consoleOutput: "Sign in with a LeetCode session to run code on LeetCode.",
                completedCaseCount: 0,
                totalCaseCount: request.testCases.count,
                issues: [
                    CodeExecutionIssue(
                        title: "Session required",
                        detail: "Run Code uses LeetCode's authenticated execution API."
                    )
                ]
            )
        }

        let handle = try await LeetCodeAPI.shared.runCode(
            questionTitleSlug: request.titleSlug,
            questionId: request.questionId,
            programmingLanguage: request.languageSlug,
            code: request.code,
            testCases: request.testCases.map(\.input).joined(separator: "\n"),
            submitCode: false
        )

        guard case .interpret(let executionID) = handle else {
            throw APIError.noData
        }

        let result = try await pollUntilComplete(id: executionID)
        let totalCases = result.totalTestcases ?? request.testCases.count
        let completed = result.totalCorrect ?? 0

        return CodeExecutionResult(
            status: (result.runSuccess == true && (result.statusMsg?.localizedCaseInsensitiveContains("accepted") == true || completed >= totalCases))
                ? .passed
                : .failed,
            consoleOutput: result.statusMsg ?? "Execution finished.",
            completedCaseCount: completed,
            totalCaseCount: totalCases,
            issues: buildIssues(from: result)
        )
    }

    func submitCode(_ request: CodeExecutionRequest) async throws -> CodeSubmissionResult {
        guard AuthManager.hasSessionCredentials() else {
            return CodeSubmissionResult(
                status: .loginRequired,
                summary: "Sign in with a LeetCode session to submit code.",
                passedCaseCount: 0,
                totalCaseCount: request.testCases.count,
                performance: nil
            )
        }

        let handle = try await LeetCodeAPI.shared.runCode(
            questionTitleSlug: request.titleSlug,
            questionId: request.questionId,
            programmingLanguage: request.languageSlug,
            code: request.code,
            testCases: request.testCases.map(\.input).joined(separator: "\n"),
            submitCode: true
        )

        guard case .submission(let submissionID) = handle else {
            throw APIError.noData
        }

        let result = try await pollUntilComplete(id: "\(submissionID)")
        let totalCases = result.totalTestcases ?? request.testCases.count
        let passedCases = result.totalCorrect ?? 0
        let summary = result.statusMsg ?? "Submission finished."

        return CodeSubmissionResult(
            status: mapSubmissionStatus(summary: summary, runSuccess: result.runSuccess),
            summary: summary,
            passedCaseCount: passedCases,
            totalCaseCount: totalCases,
            performance: buildPerformance(from: result)
        )
    }

    private func pollUntilComplete(id: String) async throws -> SubmissionCheckResult {
        for _ in 0..<12 {
            let result = try await LeetCodeAPI.shared.checkSubmission(id: id)
            let state = result.state?.lowercased()
            if state != "start" && state != "pending" {
                return result
            }
            try await Task.sleep(for: .milliseconds(800))
        }

        return try await LeetCodeAPI.shared.checkSubmission(id: id)
    }

    private func buildIssues(from result: SubmissionCheckResult) -> [CodeExecutionIssue] {
        var issues: [CodeExecutionIssue] = []

        if let compare = result.compareResult, !compare.isEmpty {
            issues.append(
                CodeExecutionIssue(
                    title: "Compare Result",
                    detail: compare
                )
            )
        }

        if let expected = result.expectedCodeAnswer?.first,
           let actual = result.codeAnswer?.first,
           expected != actual {
            issues.append(
                CodeExecutionIssue(
                    title: "Expected vs Actual",
                    detail: "Expected \(expected), got \(actual)."
                )
            )
        }

        return issues
    }

    private func mapSubmissionStatus(summary: String, runSuccess: Bool?) -> CodeSubmissionStatus {
        let normalized = summary.lowercased()
        if normalized.contains("accepted") {
            return .accepted
        }
        if normalized.contains("runtime error") {
            return .runtimeError
        }
        if runSuccess == false || normalized.contains("wrong answer") {
            return .wrongAnswer
        }
        return .runtimeError
    }

    private func buildPerformance(from result: SubmissionCheckResult) -> CodePerformanceSnapshot? {
        guard result.runtime != nil || result.memory != nil else {
            return nil
        }

        return CodePerformanceSnapshot(
            runtime: result.runtime ?? "--",
            memory: result.memory ?? "--",
            percentile: nil
        )
    }
}

struct MockCodeEditorService: CodeEditorServicing {
    func runCode(_ request: CodeExecutionRequest) async throws -> CodeExecutionResult {
        try await Task.sleep(for: .milliseconds(600))

        let normalizedCode = request.code.trimmingCharacters(in: .whitespacesAndNewlines)
        let filledCases = request.testCases.filter {
            !$0.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard !normalizedCode.isEmpty else {
            return CodeExecutionResult(
                status: .blocked,
                consoleOutput: "Add some code before running your tests.",
                completedCaseCount: 0,
                totalCaseCount: request.testCases.count,
                issues: [
                    CodeExecutionIssue(
                        title: "Empty editor",
                        detail: "The current draft is blank."
                    )
                ]
            )
        }

        guard !filledCases.isEmpty else {
            return CodeExecutionResult(
                status: .blocked,
                consoleOutput: "Create at least one test case to execute the draft.",
                completedCaseCount: 0,
                totalCaseCount: 0,
                issues: [
                    CodeExecutionIssue(
                        title: "No test cases",
                        detail: "The editor does not have any runnable inputs."
                    )
                ]
            )
        }

        let containsPlaceholder = normalizedCode.localizedCaseInsensitiveContains("todo")
            || normalizedCode.contains("fatalError")

        if containsPlaceholder {
            return CodeExecutionResult(
                status: .failed,
                consoleOutput: """
                Execution halted.
                Placeholder code is still present in the current draft.
                """,
                completedCaseCount: 0,
                totalCaseCount: filledCases.count,
                issues: [
                    CodeExecutionIssue(
                        title: "Placeholder implementation",
                        detail: "Replace TODO markers or fatal errors before running."
                    )
                ]
            )
        }

        let completed = min(filledCases.count, max(1, normalizedCode.count / 80))
        let passedAll = completed >= filledCases.count

        return CodeExecutionResult(
            status: passedAll ? .passed : .failed,
            consoleOutput: """
            Executed \(completed) of \(filledCases.count) test case(s) in mock mode.
            Language: \(request.languageSlug)
            """,
            completedCaseCount: completed,
            totalCaseCount: filledCases.count,
            issues: passedAll ? [] : [
                CodeExecutionIssue(
                    title: "Partial pass",
                    detail: "One or more custom cases still need work."
                )
            ]
        )
    }

    func submitCode(_ request: CodeExecutionRequest) async throws -> CodeSubmissionResult {
        try await Task.sleep(for: .milliseconds(900))

        let normalizedCode = request.code.trimmingCharacters(in: .whitespacesAndNewlines)
        let testCount = max(request.testCases.count, 1)
        let containsPlaceholder = normalizedCode.localizedCaseInsensitiveContains("todo")
        let looksEmpty = normalizedCode.isEmpty
        let looksRisky = normalizedCode.contains("return []") || normalizedCode.contains("return nil")

        if looksEmpty {
            return CodeSubmissionResult(
                status: .runtimeError,
                summary: "Submission was rejected because the editor draft is empty.",
                passedCaseCount: 0,
                totalCaseCount: testCount,
                performance: nil
            )
        }

        if containsPlaceholder || looksRisky {
            return CodeSubmissionResult(
                status: .wrongAnswer,
                summary: "The mock grader found obvious placeholder logic in the submission.",
                passedCaseCount: max(0, testCount - 1),
                totalCaseCount: testCount,
                performance: CodePerformanceSnapshot(
                    runtime: "92 ms",
                    memory: "18.4 MB",
                    percentile: nil
                )
            )
        }

        return CodeSubmissionResult(
            status: .accepted,
            summary: "Mock submission accepted. Wire a live LeetCode execution service to replace this adapter.",
            passedCaseCount: testCount,
            totalCaseCount: testCount,
            performance: CodePerformanceSnapshot(
                runtime: "64 ms",
                memory: "17.2 MB",
                percentile: "Beats 78%"
            )
        )
    }
}
