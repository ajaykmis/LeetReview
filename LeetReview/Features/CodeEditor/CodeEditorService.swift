import Foundation

protocol CodeEditorServicing: Sendable {
    func runCode(_ request: CodeExecutionRequest) async throws -> CodeExecutionResult
    func submitCode(_ request: CodeExecutionRequest) async throws -> CodeSubmissionResult
}

struct LiveCodeEditorService: CodeEditorServicing {
    func runCode(_ request: CodeExecutionRequest) async throws -> CodeExecutionResult {
        let hasSession = AuthManager.hasSessionCredentials()
        let sessionLen = AuthManager.getSessionCookie()?.count ?? 0
        let csrfLen = AuthManager.getCSRFToken()?.count ?? 0
        guard hasSession else {
            return CodeExecutionResult(
                status: .blocked,
                statusMessage: "No LeetCode session found (session: \(sessionLen) chars, csrf: \(csrfLen) chars). Please log out and sign in again with LeetCode.",
                completedCaseCount: 0,
                totalCaseCount: request.testCases.count,
                testCaseResults: [],
                compileError: nil,
                runtimeError: nil,
                runtime: nil,
                memory: nil
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

        let testCaseResults = buildTestCaseResults(from: result, request: request)

        let hasCompileError = result.fullCompileError != nil && !(result.fullCompileError?.isEmpty ?? true)
        let hasRuntimeError = result.fullRuntimeError != nil && !(result.fullRuntimeError?.isEmpty ?? true)

        let status: CodeExecutionStatus
        if hasCompileError || hasRuntimeError {
            status = .blocked
        } else if result.runSuccess == true && (result.statusMsg?.localizedCaseInsensitiveContains("accepted") == true || completed >= totalCases) {
            status = .passed
        } else {
            status = .failed
        }

        return CodeExecutionResult(
            status: status,
            statusMessage: result.statusMsg ?? "Execution finished.",
            completedCaseCount: completed,
            totalCaseCount: totalCases,
            testCaseResults: testCaseResults,
            compileError: result.fullCompileError ?? result.compileError,
            runtimeError: result.fullRuntimeError ?? result.runtimeError,
            runtime: result.statusRuntime ?? result.runtime,
            memory: result.statusMemory ?? result.memory
        )
    }

    func submitCode(_ request: CodeExecutionRequest) async throws -> CodeSubmissionResult {
        guard AuthManager.hasSessionCredentials() else {
            return CodeSubmissionResult(
                status: .loginRequired,
                summary: "Sign in with a LeetCode session to submit code.",
                passedCaseCount: 0,
                totalCaseCount: request.testCases.count,
                performance: nil,
                lastTestcaseInput: nil,
                lastExpectedOutput: nil,
                lastCodeOutput: nil,
                compileError: nil,
                runtimeError: nil
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
            performance: buildPerformance(from: result),
            lastTestcaseInput: result.lastTestcase,
            lastExpectedOutput: result.expectedOutput,
            lastCodeOutput: result.codeOutput?.first ?? result.codeAnswer?.first,
            compileError: result.fullCompileError ?? result.compileError,
            runtimeError: result.fullRuntimeError ?? result.runtimeError
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

    private func buildTestCaseResults(from result: SubmissionCheckResult, request: CodeExecutionRequest) -> [TestCaseResult] {
        let answers = result.codeAnswer ?? []
        let expected = result.expectedCodeAnswer ?? []
        let stdOutputs = result.stdOutputList ?? []
        let compareStr = result.compareResult ?? ""
        let inputs = request.testCases.map(\.input)

        let count = max(answers.count, expected.count)
        guard count > 0 else { return [] }

        return (0..<count).map { i in
            let passed: Bool
            if i < compareStr.count {
                let charIndex = compareStr.index(compareStr.startIndex, offsetBy: i)
                passed = compareStr[charIndex] == "1"
            } else {
                passed = i < answers.count && i < expected.count && answers[i] == expected[i]
            }

            return TestCaseResult(
                index: i,
                input: i < inputs.count ? inputs[i] : "",
                expectedOutput: i < expected.count ? expected[i] : "",
                actualOutput: i < answers.count ? answers[i] : "",
                stdOutput: i < stdOutputs.count ? stdOutputs[i] : "",
                passed: passed
            )
        }
    }

    private func mapSubmissionStatus(summary: String, runSuccess: Bool?) -> CodeSubmissionStatus {
        let normalized = summary.lowercased()
        if normalized.contains("accepted") {
            return .accepted
        }
        if normalized.contains("compile error") {
            return .compileError
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
        let rt = result.statusRuntime ?? result.runtime
        let mem = result.statusMemory ?? result.memory
        guard rt != nil || mem != nil else {
            return nil
        }

        return CodePerformanceSnapshot(
            runtime: rt ?? "--",
            memory: mem ?? "--",
            runtimePercentile: result.runtimePercentile,
            memoryPercentile: result.memoryPercentile
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
                statusMessage: "Add some code before running your tests.",
                completedCaseCount: 0,
                totalCaseCount: request.testCases.count,
                testCaseResults: [],
                compileError: nil,
                runtimeError: nil,
                runtime: nil,
                memory: nil
            )
        }

        guard !filledCases.isEmpty else {
            return CodeExecutionResult(
                status: .blocked,
                statusMessage: "Create at least one test case to execute the draft.",
                completedCaseCount: 0,
                totalCaseCount: 0,
                testCaseResults: [],
                compileError: nil,
                runtimeError: nil,
                runtime: nil,
                memory: nil
            )
        }

        let containsPlaceholder = normalizedCode.localizedCaseInsensitiveContains("todo")
            || normalizedCode.contains("fatalError")

        if containsPlaceholder {
            let mockResults = filledCases.enumerated().map { index, tc in
                TestCaseResult(
                    index: index,
                    input: tc.input,
                    expectedOutput: tc.expectedOutput,
                    actualOutput: "",
                    stdOutput: "",
                    passed: false
                )
            }
            return CodeExecutionResult(
                status: .failed,
                statusMessage: "Execution halted. Placeholder code is still present in the current draft.",
                completedCaseCount: 0,
                totalCaseCount: filledCases.count,
                testCaseResults: mockResults,
                compileError: nil,
                runtimeError: nil,
                runtime: nil,
                memory: nil
            )
        }

        let completed = min(filledCases.count, max(1, normalizedCode.count / 80))
        let passedAll = completed >= filledCases.count

        let mockResults = filledCases.enumerated().map { index, tc in
            TestCaseResult(
                index: index,
                input: tc.input,
                expectedOutput: tc.expectedOutput,
                actualOutput: index < completed ? tc.expectedOutput : "wrong",
                stdOutput: "",
                passed: index < completed
            )
        }

        return CodeExecutionResult(
            status: passedAll ? .passed : .failed,
            statusMessage: "Executed \(completed) of \(filledCases.count) test case(s) in mock mode.",
            completedCaseCount: completed,
            totalCaseCount: filledCases.count,
            testCaseResults: mockResults,
            compileError: nil,
            runtimeError: nil,
            runtime: "4 ms",
            memory: "16.2 MB"
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
                performance: nil,
                lastTestcaseInput: nil,
                lastExpectedOutput: nil,
                lastCodeOutput: nil,
                compileError: nil,
                runtimeError: "Empty code submitted"
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
                    runtimePercentile: nil,
                    memoryPercentile: nil
                ),
                lastTestcaseInput: request.testCases.last?.input,
                lastExpectedOutput: request.testCases.last?.expectedOutput,
                lastCodeOutput: "[]",
                compileError: nil,
                runtimeError: nil
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
                runtimePercentile: 78.0,
                memoryPercentile: 65.0
            ),
            lastTestcaseInput: nil,
            lastExpectedOutput: nil,
            lastCodeOutput: nil,
            compileError: nil,
            runtimeError: nil
        )
    }
}
