import Foundation
import Observation

@Observable
@MainActor
final class CodeEditorViewModel {
    let problem: CodeEditorProblemSnapshot

    private static let preferredLanguageKey = "editor_preferred_language"

    var selectedLanguageSlug: String {
        didSet {
            guard oldValue != selectedLanguageSlug else { return }
            saveDraftToDisk(for: oldValue)
            loadDraft(for: selectedLanguageSlug)
            // Remember language preference
            UserDefaults.standard.set(selectedLanguageSlug, forKey: Self.preferredLanguageKey)
        }
    }

    var code: String {
        didSet {
            // Auto-save draft on every change (debounced by SwiftUI update cycle)
            draftsByLanguageSlug[selectedLanguageSlug] = code
        }
    }
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
        service: any CodeEditorServicing = LiveCodeEditorService()
    ) {
        self.problem = problem
        self.service = service
        self.testCases = problem.initialTestCases

        // Use preferred language if available and supported, otherwise default
        let preferred = UserDefaults.standard.string(forKey: Self.preferredLanguageKey)
        let languageSlug: String
        if let preferred, problem.starterCodes.contains(where: { $0.languageSlug == preferred }) {
            languageSlug = preferred
        } else {
            languageSlug = problem.defaultLanguageSlug
        }
        self.selectedLanguageSlug = languageSlug

        // Try to load saved draft from disk, fall back to starter code
        let draftKey = Self.draftCacheKey(titleSlug: problem.titleSlug, language: languageSlug)
        if let savedDraft = UserDefaults.standard.string(forKey: draftKey), !savedDraft.isEmpty {
            self.code = savedDraft
            self.draftsByLanguageSlug[languageSlug] = savedDraft
        } else {
            let starterCode = problem.starterCodes.first(where: {
                $0.languageSlug == languageSlug
            })?.code ?? problem.starterCodes.first?.code ?? ""
            self.code = starterCode
            self.draftsByLanguageSlug[languageSlug] = starterCode
        }
    }

    /// Save drafts to disk when editor is dismissed
    func saveDraftsOnDismiss() {
        saveDraftToDisk(for: selectedLanguageSlug)
    }

    private static func draftCacheKey(titleSlug: String, language: String) -> String {
        "editor_draft_\(titleSlug)_\(language)"
    }

    private func saveDraftToDisk(for language: String) {
        guard let draft = draftsByLanguageSlug[language] else { return }
        let key = Self.draftCacheKey(titleSlug: problem.titleSlug, language: language)
        UserDefaults.standard.set(draft, forKey: key)
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

    // MARK: - Load Previous Submission

    private(set) var isLoadingPrevious = false

    func loadPreviousSubmission() async {
        guard !isLoadingPrevious else { return }
        isLoadingPrevious = true

        do {
            let submissions = try await LeetCodeAPI.shared.fetchSubmissions(
                questionSlug: problem.titleSlug,
                limit: 10
            )
            // Find most recent accepted submission in the current language if possible
            let accepted = submissions.first(where: {
                $0.statusDisplay == "Accepted" && $0.lang.lowercased() == selectedLanguageSlug.lowercased()
            }) ?? submissions.first(where: { $0.statusDisplay == "Accepted" })
              ?? submissions.first

            if let submission = accepted, let submissionId = Int(submission.id) {
                let detail = try await LeetCodeAPI.shared.fetchSubmissionDetail(submissionId: submissionId)
                code = detail.code
                draftsByLanguageSlug[selectedLanguageSlug] = detail.code
                inlineMessage = "Loaded your \(detail.lang) submission from \(submission.statusDisplay)."
            } else {
                inlineMessage = "No previous submissions found for this problem."
            }
        } catch {
            inlineMessage = "Failed to load submission: \(error.localizedDescription)"
        }

        isLoadingPrevious = false
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
                statusMessage: "Run failed: \(error.localizedDescription). Try logging out and back in.",
                completedCaseCount: 0,
                totalCaseCount: testCases.count,
                testCaseResults: [],
                compileError: nil,
                runtimeError: nil,
                runtime: nil,
                memory: nil
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
                performance: nil,
                lastTestcaseInput: nil,
                lastExpectedOutput: nil,
                lastCodeOutput: nil,
                compileError: nil,
                runtimeError: nil
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
        saveDraftToDisk(for: languageSlug)
    }

    private func loadDraft(for languageSlug: String) {
        if let existingDraft = draftsByLanguageSlug[languageSlug] {
            code = existingDraft
            return
        }

        // Try loading from disk
        let key = Self.draftCacheKey(titleSlug: problem.titleSlug, language: languageSlug)
        if let saved = UserDefaults.standard.string(forKey: key), !saved.isEmpty {
            code = saved
            draftsByLanguageSlug[languageSlug] = saved
            return
        }

        let starter = problem.starterCodes.first(where: {
            $0.languageSlug == languageSlug
        })?.code ?? problem.starterCodes.first?.code ?? ""

        draftsByLanguageSlug[languageSlug] = starter
        code = starter
    }
}
