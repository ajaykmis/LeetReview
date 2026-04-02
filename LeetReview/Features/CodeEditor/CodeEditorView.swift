import SwiftUI
import UIKit

struct CodeEditorView: View {
    @State private var viewModel: CodeEditorViewModel
    @State private var showTestCases = false
    @State private var showRunResult = false
    @State private var showSubmitResult = false

    init(
        problem: CodeEditorProblemSnapshot,
        service: any CodeEditorServicing = LiveCodeEditorService()
    ) {
        _viewModel = State(
            wrappedValue: CodeEditorViewModel(problem: problem, service: service)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Language selector bar
            languageBar

            Divider().background(Theme.Colors.textSecondary.opacity(0.2))

            // Code editor (fills remaining space)
            HighlightedCodeEditor(
                code: $viewModel.code,
                languageSlug: viewModel.selectedLanguageSlug
            )

            Divider().background(Theme.Colors.textSecondary.opacity(0.2))

            // Bottom action bar
            bottomActionBar
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle(viewModel.problem.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Theme.Spacing.md) {
                    Button {
                        UIPasteboard.general.string = viewModel.code
                        viewModel.copyCurrentCode()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.accent)
                    }

                    Button {
                        viewModel.resetCurrentDraft()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.medium)
                    }

                    Button {
                        Task { await viewModel.loadPreviousSubmission() }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .disabled(viewModel.isLoadingPrevious)
                }
            }
        }
        .alert("Editor Message", isPresented: Binding(
            get: { viewModel.inlineMessage != nil },
            set: { if !$0 { viewModel.dismissMessage() } }
        )) {
            Button("OK") { viewModel.dismissMessage() }
        } message: {
            Text(viewModel.inlineMessage ?? "")
        }
        .sheet(isPresented: $showTestCases) {
            testCasesSheet
        }
        .sheet(isPresented: $showRunResult) {
            runResultSheet
        }
        .sheet(isPresented: $showSubmitResult) {
            submitResultSheet
        }
        .onChange(of: viewModel.runResult != nil) { _, hasResult in
            if hasResult { showRunResult = true }
        }
        .onChange(of: viewModel.submissionResult != nil) { _, hasResult in
            if hasResult { showSubmitResult = true }
        }
    }

    // MARK: - Language Bar

    private var languageBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                DifficultyBadge(difficulty: viewModel.problem.difficulty)

                ForEach(viewModel.availableLanguages) { language in
                    Button {
                        viewModel.selectLanguage(language.languageSlug)
                    } label: {
                        Text(language.languageName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                viewModel.selectedLanguageSlug == language.languageSlug
                                ? Theme.Colors.background
                                : Theme.Colors.accent
                            )
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(
                                viewModel.selectedLanguageSlug == language.languageSlug
                                ? Theme.Colors.accent
                                : Theme.Colors.accent.opacity(0.12)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.card)
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Test Cases
            Button {
                showTestCases = true
            } label: {
                Label("Tests", systemImage: "list.clipboard")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.text)
            }

            Spacer()

            // Run
            Button {
                Task { await viewModel.runCode() }
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    if viewModel.isRunning {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(Theme.Colors.background)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(viewModel.isRunning ? "Running" : "Run")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.background)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(viewModel.canRun ? Theme.Colors.easy : Theme.Colors.easy.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!viewModel.canRun)

            // Submit
            Button {
                Task { await viewModel.submitCode() }
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(Theme.Colors.background)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(viewModel.isSubmitting ? "Submitting" : "Submit")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.background)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(viewModel.canSubmit ? Theme.Colors.accent : Theme.Colors.accent.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!viewModel.canSubmit)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.card)
    }

    // MARK: - Test Cases Sheet

    private var testCasesSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
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

                            Text("Input")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textSecondary)

                            TextEditor(text: $testCase.input)
                                .font(.system(.caption, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .foregroundStyle(Theme.Colors.text)
                                .frame(minHeight: 60)
                                .padding(Theme.Spacing.sm)
                                .background(Theme.Colors.background)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text("Expected Output")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textSecondary)

                            TextEditor(text: $testCase.expectedOutput)
                                .font(.system(.caption, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .foregroundStyle(Theme.Colors.text)
                                .frame(minHeight: 40)
                                .padding(Theme.Spacing.sm)
                                .background(Theme.Colors.background)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Test Cases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { showTestCases = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.addTestCase()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Run Result Sheet

    private var runResultSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if let result = viewModel.runResult {
                        StatusBanner(
                            title: result.status.rawValue,
                            subtitle: "\(result.completedCaseCount) / \(result.totalCaseCount) cases",
                            tint: executionTint(for: result.status)
                        )

                        CodeBlock(
                            code: result.consoleOutput,
                            language: "Console",
                            showCopyButton: false
                        )

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
                            .background(Theme.Colors.card)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Run Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { showRunResult = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Submit Result Sheet

    private var submitResultSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if let result = viewModel.submissionResult {
                        StatusBanner(
                            title: result.status.rawValue,
                            subtitle: result.summary,
                            tint: submissionTint(for: result.status)
                        )

                        HStack(spacing: Theme.Spacing.md) {
                            MetricCard(title: "Cases", value: "\(result.passedCaseCount)/\(result.totalCaseCount)", tint: Theme.Colors.accent)
                            MetricCard(title: "Runtime", value: result.performance?.runtime ?? "--", tint: Theme.Colors.easy)
                            MetricCard(title: "Memory", value: result.performance?.memory ?? "--", tint: Theme.Colors.medium)
                        }

                        if let percentile = result.performance?.percentile {
                            Text(percentile)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.Colors.easy)
                                .padding(Theme.Spacing.md)
                                .frame(maxWidth: .infinity)
                                .background(Theme.Colors.easy.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Submission Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { showSubmitResult = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

    private func executionTint(for status: CodeExecutionStatus) -> Color {
        switch status {
        case .passed: Theme.Colors.easy
        case .failed: Theme.Colors.hard
        case .blocked: Theme.Colors.medium
        }
    }

    private func submissionTint(for status: CodeSubmissionStatus) -> Color {
        switch status {
        case .accepted: Theme.Colors.easy
        case .wrongAnswer: Theme.Colors.hard
        case .runtimeError: Theme.Colors.medium
        case .loginRequired: Theme.Colors.accent
        }
    }
}

// MARK: - Supporting Views

private struct StatusBanner: View {
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)

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
        .background(Theme.Colors.card)
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

#Preview {
    NavigationStack {
        CodeEditorView(problem: .sample)
    }
}
