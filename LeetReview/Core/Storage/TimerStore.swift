import Foundation
import SwiftData

// MARK: - Timer Store (data access layer)

@MainActor
final class TimerStore {
    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Returns an existing timer for the slug, or creates a new one.
    func getOrCreate(titleSlug: String, title: String) -> ProblemTimer {
        if let existing = findTimer(bySlug: titleSlug) {
            return existing
        }

        let timer = ProblemTimer(titleSlug: titleSlug, title: title)
        modelContext?.insert(timer)
        try? modelContext?.save()
        return timer
    }

    /// Start the timer for a given problem.
    func startTimer(for titleSlug: String) {
        guard let timer = findTimer(bySlug: titleSlug), !timer.isRunning else { return }
        timer.lastSessionStart = Date()
        timer.isRunning = true
        timer.sessions += 1
        try? modelContext?.save()
    }

    /// Pause the timer for a given problem, accumulating elapsed time.
    func pauseTimer(for titleSlug: String) {
        guard let timer = findTimer(bySlug: titleSlug), timer.isRunning else { return }
        if let start = timer.lastSessionStart {
            timer.totalElapsedSeconds += Date().timeIntervalSince(start)
        }
        timer.lastSessionStart = nil
        timer.isRunning = false
        try? modelContext?.save()
    }

    /// Reset the timer for a given problem back to zero.
    func resetTimer(for titleSlug: String) {
        guard let timer = findTimer(bySlug: titleSlug) else { return }
        timer.totalElapsedSeconds = 0
        timer.lastSessionStart = nil
        timer.isRunning = false
        timer.sessions = 0
        try? modelContext?.save()
    }

    /// Returns all timers, ordered by date created (most recent first).
    func getAllTimers() -> [ProblemTimer] {
        let descriptor = FetchDescriptor<ProblemTimer>(
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )

        do {
            return try modelContext?.fetch(descriptor) ?? []
        } catch {
            return []
        }
    }

    // MARK: - Private

    private func findTimer(bySlug titleSlug: String) -> ProblemTimer? {
        let predicate = #Predicate<ProblemTimer> { timer in
            timer.titleSlug == titleSlug
        }
        let descriptor = FetchDescriptor<ProblemTimer>(predicate: predicate)

        do {
            return try modelContext?.fetch(descriptor).first
        } catch {
            return nil
        }
    }
}
