import Foundation
import SwiftData

@Model
final class ProblemTimer {
    @Attribute(.unique) var titleSlug: String
    var title: String
    var totalElapsedSeconds: Double
    var lastSessionStart: Date?
    var isRunning: Bool
    var sessions: Int
    var dateCreated: Date

    init(titleSlug: String, title: String) {
        self.titleSlug = titleSlug
        self.title = title
        self.totalElapsedSeconds = 0
        self.lastSessionStart = nil
        self.isRunning = false
        self.sessions = 0
        self.dateCreated = Date()
    }

    var currentElapsed: Double {
        if isRunning, let start = lastSessionStart {
            return totalElapsedSeconds + Date().timeIntervalSince(start)
        }
        return totalElapsedSeconds
    }
}
