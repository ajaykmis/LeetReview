import SwiftUI
@preconcurrency import WebKit

struct ProblemDetailView: View {
    @State private var viewModel: ProblemDetailViewModel

    init(titleSlug: String, title: String) {
        _viewModel = State(wrappedValue: ProblemDetailViewModel(
            titleSlug: titleSlug,
            title: title
        ))
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            if viewModel.isLoadingDetail && viewModel.detail == nil {
                ProgressView()
                    .tint(Theme.Colors.accent)
            } else if let error = viewModel.detailError, viewModel.detail == nil {
                errorView(message: error)
            } else if let detail = viewModel.detail {
                detailContent(detail)
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .task {
            await viewModel.loadAll()
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(_ detail: ProblemDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Header: difficulty + stats
                headerSection(detail)

                // Topic tags
                if !detail.topicTags.isEmpty {
                    tagsSection(detail.topicTags)
                }

                // Problem statement (HTML)
                if let content = detail.content, !content.isEmpty {
                    problemStatementSection(content)
                }

                // Submissions section
                submissionsSection

                Spacer(minLength: Theme.Spacing.xl)
            }
            .padding(Theme.Spacing.lg)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection(_ detail: ProblemDetail) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                DifficultyBadge(difficulty: detail.difficulty)
                Spacer()
                statsRow(detail)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    @ViewBuilder
    private func statsRow(_ detail: ProblemDetail) -> some View {
        HStack(spacing: Theme.Spacing.lg) {
            if let rate = viewModel.acceptanceRate {
                statItem(icon: "chart.bar.fill", label: rate)
            }

            statItem(
                icon: "hand.thumbsup.fill",
                label: "\(detail.likes)",
                color: Theme.Colors.easy
            )

            statItem(
                icon: "hand.thumbsdown.fill",
                label: "\(detail.dislikes)",
                color: Theme.Colors.hard
            )
        }
    }

    @ViewBuilder
    private func statItem(
        icon: String,
        label: String,
        color: Color = Theme.Colors.textSecondary
    ) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Tags

    @ViewBuilder
    private func tagsSection(_ tags: [TopicTag]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Topics")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Colors.text)

            FlowLayout(spacing: Theme.Spacing.sm) {
                ForEach(tags, id: \.name) { tag in
                    Text(tag.name)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.accent)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Problem Statement

    @ViewBuilder
    private func problemStatementSection(_ html: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Description")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Colors.text)

            ProblemHTMLView(htmlContent: html)
                .frame(minHeight: 300)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Submissions Section

    @ViewBuilder
    private var submissionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("My Submissions")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Colors.text)

                Spacer()

                if !viewModel.submissions.isEmpty {
                    Text("\(viewModel.submissions.count)")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.background)
                        .clipShape(Capsule())
                }
            }

            if viewModel.isLoadingSubmissions && viewModel.submissions.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Theme.Colors.accent)
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.lg)
            } else if let error = viewModel.submissionsError, viewModel.submissions.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.hard)
                    .padding(.vertical, Theme.Spacing.sm)
            } else if viewModel.submissions.isEmpty {
                Text("No submissions yet")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                ForEach(viewModel.submissions.prefix(5)) { submission in
                    NavigationLink {
                        CodeViewerView(submissionId: submission.id, language: submission.lang)
                    } label: {
                        SubmissionRow(submission: submission)
                    }
                }

                if viewModel.submissions.count > 5 {
                    NavigationLink {
                        SubmissionListView(
                            titleSlug: viewModel.titleSlug,
                            submissions: viewModel.submissions
                        )
                    } label: {
                        HStack {
                            Text("View all \(viewModel.submissions.count) submissions")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.accent)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.accent)
                        }
                        .padding(.top, Theme.Spacing.sm)
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Error

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.Colors.medium)

            Text("Failed to load problem")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.loadAll() }
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

// MARK: - Submission Row

struct SubmissionRow: View {
    let submission: Submission

    private var isAccepted: Bool {
        submission.statusDisplay == "Accepted"
    }

    private var statusColor: Color {
        isAccepted ? Theme.Colors.easy : Theme.Colors.hard
    }

    private var formattedDate: String {
        guard let date = Date.fromTimestamp(submission.timestamp) else {
            return "Unknown"
        }
        return date.relativeString()
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: isAccepted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(statusColor)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(submission.statusDisplay)
                    .font(.subheadline)
                    .foregroundStyle(statusColor)

                HStack(spacing: Theme.Spacing.sm) {
                    Text(submission.lang)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.accent)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - HTML WebView for Problem Statement

struct ProblemHTMLView: UIViewRepresentable {
    let htmlContent: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        loadHTML(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        loadHTML(in: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func loadHTML(in webView: WKWebView) {
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>
            * { box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
                font-size: 15px;
                line-height: 1.6;
                color: #CDD6F4;
                background-color: transparent;
                margin: 0;
                padding: 0;
                -webkit-text-size-adjust: none;
            }
            pre, code {
                font-family: 'SF Mono', 'Menlo', 'Courier New', monospace;
                font-size: 13px;
                background-color: #1E1E2E;
                border-radius: 6px;
                color: #CDD6F4;
            }
            pre {
                padding: 12px;
                overflow-x: auto;
                -webkit-overflow-scrolling: touch;
            }
            code {
                padding: 2px 6px;
            }
            pre code {
                padding: 0;
                background: none;
            }
            strong, b { color: #CDD6F4; }
            em, i { color: #A6ADC8; }
            a { color: #89B4FA; text-decoration: none; }
            img { max-width: 100%; height: auto; border-radius: 8px; }
            ul, ol { padding-left: 20px; }
            li { margin-bottom: 4px; }
            p { margin: 8px 0; }
            table {
                border-collapse: collapse;
                width: 100%;
                margin: 8px 0;
            }
            th, td {
                border: 1px solid #45475A;
                padding: 6px 10px;
                text-align: left;
            }
            th {
                background-color: #1E1E2E;
                color: #89B4FA;
            }
            sup { font-size: 0.75em; }
            sub { font-size: 0.75em; }
        </style>
        </head>
        <body>\(htmlContent)</body>
        </html>
        """
        webView.loadHTMLString(styledHTML, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow initial load, open external links in Safari
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                Task { @MainActor in
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

