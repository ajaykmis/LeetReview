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
                statusMessage: "No LeetCode session. Please sign in.",
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

        let json = try await pollUntilComplete(id: executionID)
        return parseRunResult(json: json, request: request)
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

        let json = try await pollUntilComplete(id: "\(submissionID)")
        return parseSubmitResult(json: json, request: request)
    }

    // MARK: - Polling (matches CoderGym: 2s interval, 5 attempts)

    private func pollUntilComplete(id: String) async throws -> [String: Any] {
        for _ in 0..<5 {
            try await Task.sleep(for: .seconds(2))
            let json = try await fetchCheckResult(id: id)
            let state = (json["state"] as? String)?.uppercased() ?? ""
            if state != "PENDING" && state != "STARTED" {
                return json
            }
        }
        // Final attempt
        return try await fetchCheckResult(id: id)
    }

    private func fetchCheckResult(id: String) async throws -> [String: Any] {
        let data = try await LeetCodeAPI.shared.checkSubmission(id: id)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.noData
        }
        return json
    }

    // MARK: - Run result parsing (raw JSON, like CoderGym)

    private func parseRunResult(json: [String: Any], request: CodeExecutionRequest) -> CodeExecutionResult {
        let statusMsg = json["status_msg"] as? String ?? "Unknown"
        let totalCorrect = json["total_correct"] as? Int ?? 0
        let totalTestcases = json["total_testcases"] as? Int ?? request.testCases.count

        // code_answer: array of any -> convert each element to String
        let codeAnswer: [String] = (json["code_answer"] as? [Any])?.map { "\($0)" } ?? []
        let expectedCodeAnswer: [String] = (json["expected_code_answer"] as? [Any])?.map { "\($0)" } ?? []
        let stdOutputList: [String] = (json["std_output_list"] as? [Any])?.map { "\($0)" } ?? []
        let compareResult = json["compare_result"] as? String ?? ""

        let compileError = json["full_compile_error"] as? String ?? json["compile_error"] as? String
        let runtimeError = json["full_runtime_error"] as? String ?? json["runtime_error"] as? String
        let statusRuntime = json["status_runtime"] as? String
        let statusMemory = json["status_memory"] as? String

        // Build per-test-case results
        let count = max(codeAnswer.count, expectedCodeAnswer.count, 1)
        let inputs = request.testCases.map(\.input)

        var testCaseResults: [TestCaseResult] = []
        if compileError == nil && runtimeError == nil {
            for i in 0..<count {
                let passed: Bool
                if i < compareResult.count {
                    let idx = compareResult.index(compareResult.startIndex, offsetBy: i)
                    passed = compareResult[idx] == "1"
                } else {
                    passed = i < codeAnswer.count && i < expectedCodeAnswer.count && codeAnswer[i] == expectedCodeAnswer[i]
                }
                testCaseResults.append(TestCaseResult(
                    index: i,
                    input: i < inputs.count ? inputs[i] : "",
                    expectedOutput: i < expectedCodeAnswer.count ? expectedCodeAnswer[i] : "",
                    actualOutput: i < codeAnswer.count ? codeAnswer[i] : "",
                    stdOutput: i < stdOutputList.count ? stdOutputList[i] : "",
                    passed: passed
                ))
            }
        }

        let status: CodeExecutionStatus
        if compileError != nil || runtimeError != nil {
            status = .blocked
        } else if totalCorrect >= totalTestcases && statusMsg.lowercased().contains("accepted") {
            status = .passed
        } else {
            status = .failed
        }

        return CodeExecutionResult(
            status: status,
            statusMessage: statusMsg,
            completedCaseCount: totalCorrect,
            totalCaseCount: totalTestcases,
            testCaseResults: testCaseResults,
            compileError: compileError,
            runtimeError: runtimeError,
            runtime: statusRuntime,
            memory: statusMemory
        )
    }

    // MARK: - Submit result parsing (raw JSON, like CoderGym)

    private func parseSubmitResult(json: [String: Any], request: CodeExecutionRequest) -> CodeSubmissionResult {
        let statusMsg = json["status_msg"] as? String ?? "Unknown"
        let totalCorrect = json["total_correct"] as? Int ?? 0
        let totalTestcases = json["total_testcases"] as? Int ?? request.testCases.count
        let statusRuntime = json["status_runtime"] as? String
        let statusMemory = json["status_memory"] as? String
        let runtimePercentile = json["runtime_percentile"] as? Double
        let memoryPercentile = json["memory_percentile"] as? Double
        let compileError = json["full_compile_error"] as? String ?? json["compile_error"] as? String
        let runtimeError = json["full_runtime_error"] as? String ?? json["runtime_error"] as? String
        let lastTestcase = json["last_testcase"] as? String
        let expectedOutput = json["expected_output"] as? String
        let codeOutput = (json["code_output"] as? [Any])?.first.map { "\($0)" } ?? (json["code_output"] as? String)

        let status: CodeSubmissionStatus
        let normalized = statusMsg.lowercased()
        if normalized.contains("accepted") { status = .accepted }
        else if normalized.contains("compile") { status = .compileError }
        else if normalized.contains("runtime") { status = .runtimeError }
        else if normalized.contains("wrong") { status = .wrongAnswer }
        else { status = .runtimeError }

        var performance: CodePerformanceSnapshot? = nil
        if status == .accepted, let rt = statusRuntime, let mem = statusMemory {
            performance = CodePerformanceSnapshot(
                runtime: rt, memory: mem,
                runtimePercentile: runtimePercentile,
                memoryPercentile: memoryPercentile
            )
        }

        return CodeSubmissionResult(
            status: status,
            summary: statusMsg,
            passedCaseCount: totalCorrect,
            totalCaseCount: totalTestcases,
            performance: performance,
            lastTestcaseInput: lastTestcase,
            lastExpectedOutput: expectedOutput,
            lastCodeOutput: codeOutput,
            compileError: compileError,
            runtimeError: runtimeError
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
