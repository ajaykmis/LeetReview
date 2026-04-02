import SwiftUI
import Observation

// MARK: - ViewModel

@Observable
@MainActor
final class CodeViewerViewModel {
    private(set) var submissionDetail: SubmissionDetail?
    private(set) var isLoading = false
    private(set) var error: String?

    let submissionId: String
    let language: String

    init(submissionId: String, language: String) {
        self.submissionId = submissionId
        self.language = language
    }

    func load() async {
        guard submissionDetail == nil, !isLoading else { return }
        isLoading = true
        error = nil

        do {
            guard let idInt = Int(submissionId) else {
                error = "Invalid submission ID"
                isLoading = false
                return
            }
            submissionDetail = try await LeetCodeAPI.shared.fetchSubmissionDetail(
                submissionId: idInt
            )
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    var formattedDate: String {
        guard let detail = submissionDetail,
              let date = Date.fromTimestamp(detail.timestamp) else {
            return ""
        }
        return date.dateTimeString()
    }
}

// MARK: - View

struct CodeViewerView: View {
    @State private var viewModel: CodeViewerViewModel
    @State private var showCopiedToast = false

    init(submissionId: String, language: String) {
        _viewModel = State(wrappedValue: CodeViewerViewModel(
            submissionId: submissionId,
            language: language
        ))
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.submissionDetail == nil {
                ProgressView()
                    .tint(Theme.Colors.accent)
            } else if let error = viewModel.error, viewModel.submissionDetail == nil {
                errorView(message: error)
            } else if let detail = viewModel.submissionDetail {
                codeContent(detail)
            }

            // Copied toast
            if showCopiedToast {
                VStack {
                    Spacer()
                    copiedToast
                        .padding(.bottom, Theme.Spacing.xl)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showCopiedToast)
            }
        }
        .navigationTitle("Submission")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Code Content

    @ViewBuilder
    private func codeContent(_ detail: SubmissionDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Status + metadata card
                metadataCard(detail)

                // Code block
                CodeBlock(
                    code: detail.code,
                    language: detail.lang,
                    showCopyButton: true,
                    onCopy: { copyCode(detail.code) }
                )

                Spacer(minLength: Theme.Spacing.xl)
            }
            .padding(Theme.Spacing.lg)
        }
    }

    // MARK: - Metadata Card

    @ViewBuilder
    private func metadataCard(_ detail: SubmissionDetail) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Status header
            HStack {
                Image(systemName: detail.statusDisplay == "Accepted"
                    ? "checkmark.circle.fill"
                    : "xmark.circle.fill")
                    .foregroundStyle(
                        detail.statusDisplay == "Accepted"
                            ? Theme.Colors.easy
                            : Theme.Colors.hard
                    )
                    .font(.title3)

                Text(detail.statusDisplay)
                    .font(.headline)
                    .foregroundStyle(
                        detail.statusDisplay == "Accepted"
                            ? Theme.Colors.easy
                            : Theme.Colors.hard
                    )

                Spacer()

                // Language badge
                Text(detail.lang)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Colors.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider()
                .background(Theme.Colors.textSecondary.opacity(0.3))

            // Stats grid
            HStack(spacing: Theme.Spacing.xl) {
                if let runtime = detail.runtime {
                    metadataItem(
                        icon: "bolt.fill",
                        title: "Runtime",
                        value: runtime,
                        color: Theme.Colors.accent
                    )
                }

                if let memory = detail.memory {
                    metadataItem(
                        icon: "memorychip",
                        title: "Memory",
                        value: memory,
                        color: Theme.Colors.medium
                    )
                }

                if !viewModel.formattedDate.isEmpty {
                    metadataItem(
                        icon: "calendar",
                        title: "Submitted",
                        value: viewModel.formattedDate,
                        color: Theme.Colors.textSecondary
                    )
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    @ViewBuilder
    private func metadataItem(
        icon: String,
        title: String,
        value: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Text(value)
                .font(.caption.bold())
                .foregroundStyle(Theme.Colors.text)
                .lineLimit(1)
        }
    }

    // MARK: - Copy Action

    private func copyCode(_ code: String) {
        UIPasteboard.general.string = code
        withAnimation {
            showCopiedToast = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                showCopiedToast = false
            }
        }
    }

    // MARK: - Copied Toast

    @ViewBuilder
    private var copiedToast: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.Colors.easy)
            Text("Copied to clipboard")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.text)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.card)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.Colors.medium)

            Text("Failed to load submission")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.load() }
            } label: {
                Text("Retry")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Colors.background)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(Theme.Spacing.xl)
    }
}
