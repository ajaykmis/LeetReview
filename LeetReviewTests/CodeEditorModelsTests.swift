import XCTest
@testable import LeetReview

final class CodeEditorModelsTests: XCTestCase {

    // MARK: - CodeEditorProblemSnapshot

    func testSampleSnapshotHasExpectedFields() {
        let sample = CodeEditorProblemSnapshot.sample
        XCTAssertEqual(sample.questionId, "1")
        XCTAssertEqual(sample.title, "Two Sum")
        XCTAssertEqual(sample.titleSlug, "two-sum")
        XCTAssertEqual(sample.difficulty, "Easy")
        XCTAssertEqual(sample.starterCodes.count, 3)
        XCTAssertEqual(sample.initialTestCases.count, 2)
    }

    func testDefaultLanguageSlug() {
        let sample = CodeEditorProblemSnapshot.sample
        XCTAssertEqual(sample.defaultLanguageSlug, "swift")
    }

    func testIdentifiableConformance() {
        let sample = CodeEditorProblemSnapshot.sample
        XCTAssertEqual(sample.id, "two-sum")
    }

    // MARK: - CodeEditorStarterCode

    func testStarterCodeIdentifiable() {
        let code = CodeEditorStarterCode(
            languageName: "Python",
            languageSlug: "python3",
            code: "class Solution: pass"
        )
        XCTAssertEqual(code.id, "python3")
    }

    // MARK: - CodeEditorTestCase

    func testTestCaseDefaults() {
        let tc = CodeEditorTestCase(label: "Case 1", input: "[1,2,3]")
        XCTAssertEqual(tc.label, "Case 1")
        XCTAssertEqual(tc.input, "[1,2,3]")
        XCTAssertEqual(tc.expectedOutput, "")
        XCTAssertFalse(tc.id.uuidString.isEmpty)
    }

    func testTestCaseEquality() {
        let id = UUID()
        let tc1 = CodeEditorTestCase(id: id, label: "Case", input: "x")
        let tc2 = CodeEditorTestCase(id: id, label: "Case", input: "x")
        XCTAssertEqual(tc1, tc2)
    }

    // MARK: - CodeExecutionStatus

    func testExecutionStatusRawValues() {
        XCTAssertEqual(CodeExecutionStatus.passed.rawValue, "Passed")
        XCTAssertEqual(CodeExecutionStatus.failed.rawValue, "Failed")
        XCTAssertEqual(CodeExecutionStatus.blocked.rawValue, "Blocked")
    }

    // MARK: - CodeSubmissionStatus

    func testSubmissionStatusRawValues() {
        XCTAssertEqual(CodeSubmissionStatus.accepted.rawValue, "Accepted")
        XCTAssertEqual(CodeSubmissionStatus.wrongAnswer.rawValue, "Wrong Answer")
        XCTAssertEqual(CodeSubmissionStatus.runtimeError.rawValue, "Runtime Error")
        XCTAssertEqual(CodeSubmissionStatus.compileError.rawValue, "Compile Error")
        XCTAssertEqual(CodeSubmissionStatus.loginRequired.rawValue, "Login Required")
    }

    // MARK: - CodePerformanceSnapshot

    func testPerformanceSnapshotHashable() {
        let p1 = CodePerformanceSnapshot(runtime: "10 ms", memory: "5 MB", runtimePercentile: 90.0, memoryPercentile: 85.0)
        let p2 = CodePerformanceSnapshot(runtime: "10 ms", memory: "5 MB", runtimePercentile: 90.0, memoryPercentile: 85.0)
        XCTAssertEqual(p1, p2)
    }
}
