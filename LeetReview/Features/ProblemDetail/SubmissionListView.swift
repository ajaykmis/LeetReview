import SwiftUI

struct SubmissionListView: View {
    let titleSlug: String
    let submissions: [Submission]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            if submissions.isEmpty {
                emptyState
            } else {
                submissionsList
            }
        }
        .navigationTitle("Submissions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
    }

    // MARK: - Submissions List

    @ViewBuilder
    private var submissionsList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                ForEach(submissions) { submission in
                    NavigationLink {
                        CodeViewerView(
                            submissionId: submission.id,
                            language: submission.lang
                        )
                    } label: {
                        SubmissionListRow(submission: submission)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Colors.textSecondary)

            Text("No submissions yet")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            Text("Submit a solution on LeetCode to see it here.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Submission List Row

struct SubmissionListRow: View {
    let submission: Submission

    private var isAccepted: Bool {
        submission.statusDisplay == "Accepted"
    }

    private var statusColor: Color {
        switch submission.statusDisplay {
        case "Accepted":
            return Theme.Colors.easy
        case "Wrong Answer", "Runtime Error", "Compile Error", "Time Limit Exceeded",
             "Memory Limit Exceeded":
            return Theme.Colors.hard
        default:
            return Theme.Colors.medium
        }
    }

    private var statusIcon: String {
        switch submission.statusDisplay {
        case "Accepted":
            return "checkmark.circle.fill"
        case "Wrong Answer":
            return "xmark.circle.fill"
        case "Runtime Error", "Compile Error":
            return "exclamationmark.triangle.fill"
        case "Time Limit Exceeded":
            return "clock.fill"
        case "Memory Limit Exceeded":
            return "memorychip"
        default:
            return "questionmark.circle.fill"
        }
    }

    private var formattedDate: String {
        guard let date = Date.fromTimestamp(submission.timestamp) else {
            return "Unknown date"
        }
        return date.dateTimeString()
    }

    private var relativeDate: String {
        guard let date = Date.fromTimestamp(submission.timestamp) else {
            return ""
        }
        return date.relativeString()
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Status icon
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 32)

            // Submission info
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(submission.statusDisplay)
                    .font(.subheadline.bold())
                    .foregroundStyle(statusColor)

                HStack(spacing: Theme.Spacing.sm) {
                    // Language badge
                    Text(submission.lang)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(relativeDate)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}
