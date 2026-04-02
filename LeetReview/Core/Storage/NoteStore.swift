import Foundation
import SwiftData

// MARK: - Note Store (data access layer)

@MainActor
final class NoteStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Save or update a note for a problem. Creates a new note if one doesn't exist.
    func saveNote(
        titleSlug: String,
        title: String,
        difficulty: String,
        noteText: String
    ) {
        if let existing = getNote(bySlug: titleSlug) {
            existing.noteText = noteText
            existing.dateModified = .now
        } else {
            let note = ProblemNote(
                titleSlug: titleSlug,
                title: title,
                difficulty: difficulty,
                noteText: noteText
            )
            modelContext.insert(note)
        }
        try? modelContext.save()
    }

    /// Find a note by its title slug.
    func getNote(bySlug titleSlug: String) -> ProblemNote? {
        let predicate = #Predicate<ProblemNote> { note in
            note.titleSlug == titleSlug
        }
        let descriptor = FetchDescriptor<ProblemNote>(predicate: predicate)

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            return nil
        }
    }

    /// Returns all bookmarked notes, ordered by date modified (most recent first).
    func getAllBookmarks() -> [ProblemNote] {
        let predicate = #Predicate<ProblemNote> { note in
            note.isBookmarked == true
        }
        let descriptor = FetchDescriptor<ProblemNote>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.dateModified, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    /// Returns all notes, ordered by date modified (most recent first).
    func getAllNotes() -> [ProblemNote] {
        let descriptor = FetchDescriptor<ProblemNote>(
            sortBy: [SortDescriptor(\.dateModified, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    /// Toggle the bookmark state for a problem. Creates a note entry if needed.
    func toggleBookmark(
        titleSlug: String,
        title: String,
        difficulty: String
    ) {
        if let existing = getNote(bySlug: titleSlug) {
            existing.isBookmarked.toggle()
            existing.dateModified = .now
        } else {
            let note = ProblemNote(
                titleSlug: titleSlug,
                title: title,
                difficulty: difficulty,
                isBookmarked: true
            )
            modelContext.insert(note)
        }
        try? modelContext.save()
    }

    /// Delete a note entirely.
    func deleteNote(_ note: ProblemNote) {
        modelContext.delete(note)
        try? modelContext.save()
    }
}
