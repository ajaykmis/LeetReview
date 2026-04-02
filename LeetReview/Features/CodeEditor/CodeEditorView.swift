import SwiftUI
import UIKit

struct CodeEditorView: View {
    @State private var viewModel: CodeEditorViewModel
    @State private var showTestCases = false
    @State private var showRunResult = false
    @State private var showSubmitResult = false
    @State private var runResultVersion = 0
    @State private var submitResultVersion = 0
    @State private var selectedRunCaseIndex = 0

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
        .onChange(of: viewModel.isRunning) { _, isRunning in
            if !isRunning && viewModel.runResult != nil {
                runResultVersion += 1
                showRunResult = true
            }
        }
        .onChange(of: viewModel.isSubmitting) { _, isSubmitting in
            if !isSubmitting && viewModel.submissionResult != nil {
                submitResultVersion += 1
                showSubmitResult = true
            }
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
                        // Status banner with pass/fail count and runtime
                        StatusBanner(
                            title: result.status.rawValue,
                            subtitle: {
                                var parts = ["\(result.completedCaseCount) / \(result.totalCaseCount) cases"]
                                if let rt = result.runtime { parts.append(rt) }
                                return parts.joined(separator: "  |  ")
                            }(),
                            tint: executionTint(for: result.status)
                        )

                        // Compile error
                        if let compileErr = result.compileError, !compileErr.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Compile Error")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.Colors.hard)
                                Text(compileErr)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Theme.Colors.hard)
                                    .textSelection(.enabled)
                            }
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Colors.hard.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Runtime error
                        if let runtimeErr = result.runtimeError, !runtimeErr.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Runtime Error")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.Colors.hard)
                                Text(runtimeErr)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Theme.Colors.hard)
                                    .textSelection(.enabled)
                            }
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Colors.hard.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Test case tabs and details
                        if !result.testCaseResults.isEmpty {
                            // Horizontal scrollable case tabs
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    ForEach(Array(result.testCaseResults.enumerated()), id: \.element.id) { index, caseResult in
                                        Button {
                                            selectedRunCaseIndex = index
                                        } label: {
                                            HStack(spacing: Theme.Spacing.xs) {
                                                Image(systemName: caseResult.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(caseResult.passed ? Theme.Colors.easy : Theme.Colors.hard)
                                                Text("Case \(index + 1)")
                                                    .font(.caption.weight(.semibold))
                                            }
                                            .foregroundStyle(
                                                selectedRunCaseIndex == index
                                                ? Theme.Colors.background
                                                : Theme.Colors.text
                                            )
                                            .padding(.horizontal, Theme.Spacing.md)
                                            .padding(.vertical, Theme.Spacing.sm)
                                            .background(
                                                selectedRunCaseIndex == index
                                                ? Theme.Colors.accent
                                                : Theme.Colors.card
                                            )
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }

                            // Selected case details
                            if selectedRunCaseIndex < result.testCaseResults.count {
                                let selected = result.testCaseResults[selectedRunCaseIndex]

                                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                    // Input
                                    if !selected.input.isEmpty {
                                        runCaseField(title: "Input", value: selected.input, color: Theme.Colors.textSecondary)
                                    }

                                    // stdout
                                    if !selected.stdOutput.isEmpty {
                                        runCaseField(title: "stdout", value: selected.stdOutput, color: Theme.Colors.textSecondary)
                                    }

                                    // Your Output
                                    if !selected.actualOutput.isEmpty {
                                        runCaseField(
                                            title: "Your Output",
                                            value: selected.actualOutput,
                                            color: selected.passed ? Theme.Colors.easy : Theme.Colors.hard
                                        )
                                    }

                                    // Expected
                                    if !selected.expectedOutput.isEmpty {
                                        runCaseField(title: "Expected", value: selected.expectedOutput, color: Theme.Colors.easy)
                                    }
                                }
                                .padding(Theme.Spacing.md)
                                .background(Theme.Colors.card)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        } else if result.compileError == nil && result.runtimeError == nil {
                            // Fallback status message when no test case results and no errors
                            CodeBlock(
                                code: result.statusMessage,
                                language: "Console",
                                showCopyButton: false
                            )
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

    private func runCaseField(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(color)
                .textSelection(.enabled)
                .padding(Theme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
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

                        // Accepted: show performance metrics with percentiles
                        if result.status == .accepted {
                            if let perf = result.performance {
                                HStack(spacing: Theme.Spacing.md) {
                                    MetricCard(title: "Cases", value: "\(result.passedCaseCount)/\(result.totalCaseCount)", tint: Theme.Colors.accent)

                                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                        Text("Runtime")
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                        Text(perf.runtime)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Theme.Colors.text)
                                        if let pct = perf.runtimePercentile {
                                            Text("Beats \(String(format: "%.1f", pct))%")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(Theme.Colors.easy)
                                        }
                                    }
                                    .padding(Theme.Spacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.Colors.easy.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                        Text("Memory")
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                        Text(perf.memory)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Theme.Colors.text)
                                        if let pct = perf.memoryPercentile {
                                            Text("Beats \(String(format: "%.1f", pct))%")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(Theme.Colors.easy)
                                        }
                                    }
                                    .padding(Theme.Spacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.Colors.medium.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                // Accepted icon
                                HStack {
                                    Spacer()
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(Theme.Colors.easy)
                                    Spacer()
                                }
                                .padding(.vertical, Theme.Spacing.sm)
                            }
                        }

                        // Wrong Answer: show failing test case details
                        if result.status == .wrongAnswer {
                            HStack(spacing: Theme.Spacing.md) {
                                MetricCard(title: "Cases", value: "\(result.passedCaseCount)/\(result.totalCaseCount)", tint: Theme.Colors.hard)
                            }

                            if result.lastTestcaseInput != nil || result.lastExpectedOutput != nil || result.lastCodeOutput != nil {
                                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                                    Text("Failing Test Case")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.Colors.hard)

                                    if let input = result.lastTestcaseInput, !input.isEmpty {
                                        runCaseField(title: "Input", value: input, color: Theme.Colors.textSecondary)
                                    }
                                    if let expected = result.lastExpectedOutput, !expected.isEmpty {
                                        runCaseField(title: "Expected", value: expected, color: Theme.Colors.easy)
                                    }
                                    if let actual = result.lastCodeOutput, !actual.isEmpty {
                                        runCaseField(title: "Your Output", value: actual, color: Theme.Colors.hard)
                                    }
                                }
                                .padding(Theme.Spacing.md)
                                .background(Theme.Colors.card)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Compile Error
                        if result.status == .compileError, let compileErr = result.compileError, !compileErr.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Compile Error")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.Colors.hard)
                                Text(compileErr)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Theme.Colors.hard)
                                    .textSelection(.enabled)
                            }
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Colors.hard.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Runtime Error
                        if result.status == .runtimeError, let runtimeErr = result.runtimeError, !runtimeErr.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                Text("Runtime Error")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.Colors.hard)
                                Text(runtimeErr)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Theme.Colors.hard)
                                    .textSelection(.enabled)
                            }
                            .padding(Theme.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Colors.hard.opacity(0.08))
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
        case .compileError: Theme.Colors.hard
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
