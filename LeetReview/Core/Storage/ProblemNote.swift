import Foundation
import SwiftData

@Model
final class ProblemNote {
    @Attribute(.unique) var titleSlug: String
    var title: String
    var difficulty: String
    var noteText: String
    var isBookmarked: Bool
    var dateCreated: Date
    var dateModified: Date

    init(
        titleSlug: String,
        title: String,
        difficulty: String,
        noteText: String = "",
        isBookmarked: Bool = false,
        dateCreated: Date = .now,
        dateModified: Date = .now
    ) {
        self.titleSlug = titleSlug
        self.title = title
        self.difficulty = difficulty
        self.noteText = noteText
        self.isBookmarked = isBookmarked
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }
}
