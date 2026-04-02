import SwiftUI
import SwiftData

struct BookmarksView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @State private var bookmarks: [ProblemNote] = []

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            if bookmarks.isEmpty {
                emptyView
            } else {
                bookmarkList
            }
        }
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .toolbarColorScheme(themeManager.toolbarColorScheme, for: .navigationBar)
        .task {
            loadBookmarks()
        }
    }

    // MARK: - Bookmark List

    private var bookmarkList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Text("\(bookmarks.count) bookmarked")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)

                ForEach(bookmarks, id: \.titleSlug) { note in
                    NavigationLink {
                        ProblemDetailView(
                            titleSlug: note.titleSlug,
                            title: note.title
                        )
                    } label: {
                        BookmarkRow(note: note)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "bookmark")
                .font(.largeTitle)
                .foregroundStyle(Theme.Colors.textSecondary)

            Text("No bookmarks yet")
                .font(.headline)
                .foregroundStyle(Theme.Colors.text)

            Text("Bookmark problems from the detail page to find them here quickly.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }

    // MARK: - Helpers

    private func loadBookmarks() {
        let store = NoteStore(modelContext: modelContext)
        bookmarks = store.getAllBookmarks()
    }
}

// MARK: - Bookmark Row

private struct BookmarkRow: View {
    let note: ProblemNote

    private var formattedDate: String {
        note.dateModified.relativeString()
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "bookmark.fill")
                .font(.body)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(note.title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.sm) {
                    DifficultyBadge(difficulty: note.difficulty)

                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            if !note.noteText.isEmpty {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.medium)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}
