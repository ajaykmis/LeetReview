import SwiftUI
import UIKit

struct CodeEditorView: View {
    @State private var viewModel: CodeEditorViewModel

    init(
        problem: CodeEditorProblemSnapshot,
        service: any CodeEditorServicing = LiveCodeEditorService()
    ) {
        _viewModel = State(
            wrappedValue: CodeEditorViewModel(problem: problem, service: service)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ProblemSummaryCard(viewModel: viewModel)
                EditorToolbar(viewModel: viewModel)
                EditableCodeCard(viewModel: viewModel)
                TestCaseSection(viewModel: viewModel)
                RunResultSection(viewModel: viewModel)
                SubmitResultSection(viewModel: viewModel)
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle(viewModel.problem.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .alert("Editor Message", isPresented: Binding(
            get: { viewModel.inlineMessage != nil },
            set: { if !$0 { viewModel.dismissMessage() } }
        )) {
            Button("OK") {
                viewModel.dismissMessage()
            }
        } message: {
            Text(viewModel.inlineMessage ?? "")
        }
    }
}

private struct ProblemSummaryCard: View {
    let viewModel: CodeEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(viewModel.problem.title)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.Colors.text)

                    Text(viewModel.problem.titleSlug)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                DifficultyBadge(difficulty: viewModel.problem.difficulty)
            }

            ForEach(Array(viewModel.summaryParagraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

private struct EditorToolbar: View {
    @Bindable var viewModel: CodeEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Language")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.availableLanguages) { language in
                        Button {
                            viewModel.selectLanguage(language.languageSlug)
                        } label: {
                            Text(language.languageName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(
                                    viewModel.selectedLanguageSlug == language.languageSlug
                                    ? Theme.Colors.background
                                    : Theme.Colors.accent
                                )
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(
                                    viewModel.selectedLanguageSlug == language.languageSlug
                                    ? Theme.Colors.accent
                                    : Theme.Colors.accent.opacity(0.12)
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                ActionButton(
                    title: viewModel.isRunning ? "Running..." : "Run",
                    systemImage: "play.fill",
                    tint: Theme.Colors.easy,
                    isEnabled: viewModel.canRun
                ) {
                    Task {
                        await viewModel.runCode()
                    }
                }

                ActionButton(
                    title: viewModel.isSubmitting ? "Submitting..." : "Submit",
                    systemImage: "paperplane.fill",
                    tint: Theme.Colors.accent,
                    isEnabled: viewModel.canSubmit
                ) {
                    Task {
                        await viewModel.submitCode()
                    }
                }

                ActionButton(
                    title: "Reset",
                    systemImage: "arrow.counterclockwise",
                    tint: Theme.Colors.medium,
                    isEnabled: true
                ) {
                    viewModel.resetCurrentDraft()
                }

                ActionButton(
                    title: viewModel.isLoadingPrevious ? "Loading..." : "Previous",
                    systemImage: "clock.arrow.circlepath",
                    tint: Theme.Colors.textSecondary,
                    isEnabled: !viewModel.isLoadingPrevious
                ) {
                    Task {
                        await viewModel.loadPreviousSubmission()
                    }
                }

                Spacer()
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

private struct EditableCodeCard: View {
    @Bindable var viewModel: CodeEditorViewModel
    @State private var isFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Editor")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.text)

                    HStack(spacing: Theme.Spacing.xs) {
                        Text(viewModel.selectedLanguage?.languageName ?? "")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.Colors.accent)
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("Drafts kept per language")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                Spacer()

                Button {
                    UIPasteboard.general.string = viewModel.code
                    viewModel.copyCurrentCode()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.accent)
                }
            }

            HighlightedCodeEditor(
                code: $viewModel.code,
                languageSlug: viewModel.selectedLanguageSlug,
                onFocusChange: { focused in
                    isFocused = focused
                }
            )
            .frame(minHeight: 320)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ? Theme.Colors.accent : Theme.Colors.textSecondary.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

private struct TestCaseSection: View {
    @Bindable var viewModel: CodeEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Test Cases")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.text)

                    Text("Edit custom inputs before running code.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Button {
                    viewModel.addTestCase()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.accent)
                }
            }

            ForEach($viewModel.testCases) { $testCase in
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        TextField("Label", text: $testCase.label)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Theme.Colors.text)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Button {
                            viewModel.duplicateTestCase(testCase)
                        } label: {
                            Image(systemName: "plus.square.on.square")
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }

                    Group {
                        Text("Input")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)

                        textArea(text: $testCase.input, prompt: "nums = [2,7,11,15], target = 9")

                        Text("Expected Output")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)

                        textArea(text: $testCase.expectedOutput, prompt: "[0,1]")
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if viewModel.testCases.count > 1 {
                Button(role: .destructive) {
                    viewModel.removeTestCases(at: IndexSet(integer: viewModel.testCases.count - 1))
                } label: {
                    Label("Remove Last Case", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private func textArea(text: Binding<String>, prompt: String) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(prompt)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
            }

            TextEditor(text: text)
                .font(.system(.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .foregroundStyle(Theme.Colors.text)
                .frame(minHeight: 74)
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct RunResultSection: View {
    let viewModel: CodeEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "Run Result", systemImage: "waveform.path.ecg")

            if let result = viewModel.runResult {
                StatusBanner(
                    title: result.status.rawValue,
                    subtitle: "\(result.completedCaseCount) / \(result.totalCaseCount) cases completed",
                    tint: tint(for: result.status)
                )

                CodeBlock(
                    code: result.consoleOutput,
                    language: "Console",
                    showCopyButton: false
                )

                if !result.issues.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        ForEach(result.issues) { issue in
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(issue.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.Colors.text)
                                Text(issue.detail)
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            } else {
                PlaceholderCard(
                    title: "No run yet",
                    message: "Use Run to execute the current draft against LeetCode."
                )
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private func tint(for status: CodeExecutionStatus) -> Color {
        switch status {
        case .passed: Theme.Colors.easy
        case .failed: Theme.Colors.hard
        case .blocked: Theme.Colors.medium
        }
    }
}

private struct SubmitResultSection: View {
    let viewModel: CodeEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(title: "Submit Result", systemImage: "checkmark.seal")

            if let result = viewModel.submissionResult {
                StatusBanner(
                    title: result.status.rawValue,
                    subtitle: result.summary,
                    tint: tint(for: result.status)
                )

                HStack(spacing: Theme.Spacing.md) {
                    MetricCard(
                        title: "Cases",
                        value: "\(result.passedCaseCount)/\(result.totalCaseCount)",
                        tint: Theme.Colors.accent
                    )

                    MetricCard(
                        title: "Runtime",
                        value: result.performance?.runtime ?? "--",
                        tint: Theme.Colors.easy
                    )

                    MetricCard(
                        title: "Memory",
                        value: result.performance?.memory ?? "--",
                        tint: Theme.Colors.medium
                    )
                }

                if let percentile = result.performance?.percentile {
                    Text(percentile)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            } else {
                PlaceholderCard(
                    title: "No submission yet",
                    message: "Use Submit to send the current draft for a LeetCode verdict."
                )
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    private func tint(for status: CodeSubmissionStatus) -> Color {
        switch status {
        case .accepted: Theme.Colors.easy
        case .wrongAnswer: Theme.Colors.hard
        case .runtimeError: Theme.Colors.medium
        case .loginRequired: Theme.Colors.accent
        }
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEnabled ? Theme.Colors.background : Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(isEnabled ? tint : Theme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct StatusBanner: View {
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.text)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.text)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct PlaceholderCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.text)

            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private func sectionHeader(title: String, systemImage: String) -> some View {
    HStack(spacing: Theme.Spacing.sm) {
        Image(systemName: systemImage)
            .foregroundStyle(Theme.Colors.accent)
        Text(title)
            .font(.headline)
            .foregroundStyle(Theme.Colors.text)
    }
}

#Preview {
    NavigationStack {
        CodeEditorView(problem: .sample)
    }
}
