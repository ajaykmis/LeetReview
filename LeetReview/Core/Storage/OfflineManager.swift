import Foundation
import Network
import Observation

/// Tracks network connectivity and manages the set of problems saved for offline access.
/// Uses `NWPathMonitor` to observe reachability and persists saved slugs in UserDefaults.
@Observable
@MainActor
final class OfflineManager {
    // MARK: - State

    private(set) var isOffline = false
    private(set) var savedProblemSlugs: Set<String> = []

    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.leetreview.networkMonitor", qos: .utility)
    private static let savedSlugsKey = "savedOfflineSlugs"

    // MARK: - Init

    init() {
        // Restore persisted slugs
        if let stored = UserDefaults.standard.array(forKey: Self.savedSlugsKey) as? [String] {
            savedProblemSlugs = Set(stored)
        }

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOffline = (path.status != .satisfied)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Public API

    func saveProblemForOffline(titleSlug: String) {
        savedProblemSlugs.insert(titleSlug)
        persistSlugs()
    }

    func removeSavedProblem(titleSlug: String) {
        savedProblemSlugs.remove(titleSlug)
        persistSlugs()
    }

    func isSaved(titleSlug: String) -> Bool {
        savedProblemSlugs.contains(titleSlug)
    }

    var savedCount: Int {
        savedProblemSlugs.count
    }

    // MARK: - Private helpers

    private func persistSlugs() {
        UserDefaults.standard.set(Array(savedProblemSlugs), forKey: Self.savedSlugsKey)
    }
}
