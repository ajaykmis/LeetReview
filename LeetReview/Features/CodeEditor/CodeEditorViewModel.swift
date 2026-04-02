import Foundation
import Observation

@Observable
@MainActor
final class CodeEditorViewModel {
    let problem: CodeEditorProblemSnapshot

    var selectedLanguageSlug: String {
        didSet {
            guard oldValue != selectedLanguageSlug else { return }
            persistCurrentDraft(for: oldValue)
            loadDraft(for: selectedLanguageSlug)
        }
    }

    var code: String
    var testCases: [CodeEditorTestCase]

    private(set) var runResult: CodeExecutionResult?
    private(set) var submissionResult: CodeSubmissionResult?
    private(set) var isRunning = false
    private(set) var isSubmitting = false
    private(set) var inlineMessage: String?

    private let service: any CodeEditorServicing
    private var draftsByLanguageSlug: [String: String] = [:]

    init(
        problem: CodeEditorProblemSnapshot,
        service: any CodeEditorServicing = MockCodeEditorService()
    ) {
        self.problem = problem
        self.service = service
        self.selectedLanguageSlug = problem.defaultLanguageSlug
        self.testCases = problem.initialTestCases

        let defaultCode = problem.starterCodes.first(where: {
            $0.languageSlug == problem.defaultLanguageSlug
        })?.code ?? problem.starterCodes.first?.code ?? ""

        self.code = defaultCode
        self.draftsByLanguageSlug[problem.defaultLanguageSlug] = defaultCode
    }

    var selectedLanguage: CodeEditorStarterCode? {
        problem.starterCodes.first(where: { $0.languageSlug == selectedLanguageSlug })
    }

    var availableLanguages: [CodeEditorStarterCode] {
        problem.starterCodes
    }

    var canRun: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isRunning
    }

    var canSubmit: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var summaryParagraphs: [String] {
        problem.summary
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func selectLanguage(_ languageSlug: String) {
        selectedLanguageSlug = languageSlug
    }

    func addTestCase() {
        let nextIndex = testCases.count + 1
        testCases.append(
            CodeEditorTestCase(
                label: "Case \(nextIndex)",
                input: "",
                expectedOutput: ""
            )
        )
    }

    func duplicateTestCase(_ testCase: CodeEditorTestCase) {
        let nextIndex = testCases.count + 1
        testCases.append(
            CodeEditorTestCase(
                label: "Case \(nextIndex)",
                input: testCase.input,
                expectedOutput: testCase.expectedOutput
            )
        )
    }

    func removeTestCases(at offsets: IndexSet) {
        testCases.remove(atOffsets: offsets)
        if testCases.isEmpty {
            addTestCase()
        }
    }

    func resetCurrentDraft() {
        let starter = selectedLanguage?.code ?? ""
        code = starter
        draftsByLanguageSlug[selectedLanguageSlug] = starter
        inlineMessage = "Reset the \(selectedLanguage?.languageName ?? "current") draft to its starter code."
    }

    func copyCurrentCode() {
        inlineMessage = "Copied the current draft."
    }

    func dismissMessage() {
        inlineMessage = nil
    }

    func runCode() async {
        guard !isRunning else { return }

        isRunning = true
        inlineMessage = nil
        submissionResult = nil
        persistCurrentDraft(for: selectedLanguageSlug)

        do {
            runResult = try await service.runCode(currentRequest())
        } catch {
            runResult = CodeExecutionResult(
                status: .blocked,
                consoleOutput: "The run request failed: \(error.localizedDescription)",
                completedCaseCount: 0,
                totalCaseCount: testCases.count,
                issues: []
            )
        }

        isRunning = false
    }

    func submitCode() async {
        guard !isSubmitting else { return }

        isSubmitting = true
        inlineMessage = nil
        persistCurrentDraft(for: selectedLanguageSlug)

        do {
            submissionResult = try await service.submitCode(currentRequest())
        } catch {
            submissionResult = CodeSubmissionResult(
                status: .runtimeError,
                summary: "The submission request failed: \(error.localizedDescription)",
                passedCaseCount: 0,
                totalCaseCount: testCases.count,
                performance: nil
            )
        }

        isSubmitting = false
    }

    private func currentRequest() -> CodeExecutionRequest {
        CodeExecutionRequest(
            questionId: problem.questionId,
            titleSlug: problem.titleSlug,
            languageSlug: selectedLanguageSlug,
            code: code,
            testCases: testCases
        )
    }

    private func persistCurrentDraft(for languageSlug: String) {
        draftsByLanguageSlug[languageSlug] = code
    }

    private func loadDraft(for languageSlug: String) {
        if let existingDraft = draftsByLanguageSlug[languageSlug] {
            code = existingDraft
            return
        }

        let starter = problem.starterCodes.first(where: {
            $0.languageSlug == languageSlug
        })?.code ?? problem.starterCodes.first?.code ?? ""

        draftsByLanguageSlug[languageSlug] = starter
        code = starter
    }
}
