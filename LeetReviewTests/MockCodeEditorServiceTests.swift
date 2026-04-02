import XCTest
@testable import LeetReview

final class MockCodeEditorServiceTests: XCTestCase {

    private let service = MockCodeEditorService()

    private func makeRequest(code: String, testCases: [CodeEditorTestCase]? = nil) -> CodeExecutionRequest {
        CodeExecutionRequest(
            questionId: "1",
            titleSlug: "two-sum",
            languageSlug: "python3",
            code: code,
            testCases: testCases ?? [
                CodeEditorTestCase(label: "Case 1", input: "[2,7,11,15]", expectedOutput: "[0,1]")
            ]
        )
    }

    // MARK: - runCode tests

    func testRunEmptyCodeReturnsBlocked() async throws {
        let result = try await service.runCode(makeRequest(code: ""))
        XCTAssertEqual(result.status, .blocked)
        XCTAssertTrue(result.consoleOutput.contains("Add some code"))
    }

    func testRunWithNoTestCasesReturnsBlocked() async throws {
        let request = makeRequest(code: "return 1", testCases: [
            CodeEditorTestCase(label: "Empty", input: "", expectedOutput: "")
        ])
        let result = try await service.runCode(request)
        XCTAssertEqual(result.status, .blocked)
    }

    func testRunWithTodoReturnsFailedPlaceholder() async throws {
        let result = try await service.runCode(makeRequest(code: "// TODO: implement"))
        XCTAssertEqual(result.status, .failed)
        XCTAssertTrue(result.issues.contains(where: { $0.title == "Placeholder implementation" }))
    }

    func testRunWithFatalErrorReturnsFailedPlaceholder() async throws {
        let result = try await service.runCode(makeRequest(code: "fatalError()"))
        XCTAssertEqual(result.status, .failed)
    }

    func testRunValidCodeReturnsPassed() async throws {
        let longCode = String(repeating: "x", count: 200) // long enough to pass all cases
        let result = try await service.runCode(makeRequest(code: longCode))
        XCTAssertEqual(result.status, .passed)
    }

    // MARK: - submitCode tests

    func testSubmitEmptyCodeReturnsRuntimeError() async throws {
        let result = try await service.submitCode(makeRequest(code: ""))
        XCTAssertEqual(result.status, .runtimeError)
    }

    func testSubmitTodoCodeReturnsWrongAnswer() async throws {
        let result = try await service.submitCode(makeRequest(code: "TODO: solve"))
        XCTAssertEqual(result.status, .wrongAnswer)
        XCTAssertNotNil(result.performance)
    }

    func testSubmitReturnNilReturnsWrongAnswer() async throws {
        let result = try await service.submitCode(makeRequest(code: "return nil"))
        XCTAssertEqual(result.status, .wrongAnswer)
    }

    func testSubmitValidCodeReturnsAccepted() async throws {
        let result = try await service.submitCode(makeRequest(code: "class Solution: def solve(): return [0,1]"))
        XCTAssertEqual(result.status, .accepted)
        XCTAssertNotNil(result.performance)
        XCTAssertEqual(result.performance?.percentile, "Beats 78%")
    }
}
