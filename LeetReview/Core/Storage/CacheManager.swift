import Foundation

/// Simple disk-based cache for offline access to problems and solutions.
/// Uses the app's Caches directory with JSON-encoded files.
final class CacheManager: Sendable {
    static let shared = CacheManager()

    private let cacheDirectory: URL
    private nonisolated(unsafe) let fileManager = FileManager.default

    private init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDir.appendingPathComponent("LeetReviewCache", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Core Operations

    /// Cache data for a given key.
    func cache(key: String, data: Data) {
        let fileURL = fileURL(for: key)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Cache an Encodable value for a given key.
    func cache<T: Encodable>(key: String, value: T) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        cache(key: key, data: data)
    }

    /// Retrieve cached data for a given key.
    func get(key: String) -> Data? {
        let fileURL = fileURL(for: key)
        return try? Data(contentsOf: fileURL)
    }

    /// Retrieve and decode a cached value for a given key.
    func get<T: Decodable>(key: String, as type: T.Type) -> T? {
        guard let data = get(key: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Check if a cache entry exists for the given key.
    func exists(key: String) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: key).path)
    }

    /// Remove a specific cache entry.
    func remove(key: String) {
        let fileURL = fileURL(for: key)
        try? fileManager.removeItem(at: fileURL)
    }

    /// Clear all cached data.
    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Returns the total size of the cache in bytes.
    func cacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else { continue }
            totalSize += Int64(fileSize)
        }
        return totalSize
    }

    /// Returns a human-readable string for the cache size (e.g., "2.3 MB").
    func cacheSizeString() -> String {
        let bytes = cacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Convenience Keys

    /// Cache key for a problem's detail.
    static func problemDetailKey(_ titleSlug: String) -> String {
        "problem_detail_\(titleSlug)"
    }

    /// Cache key for a submission's code.
    static func submissionCodeKey(_ submissionId: String) -> String {
        "submission_code_\(submissionId)"
    }

    /// Cache key for a user's submissions for a problem.
    static func submissionListKey(_ titleSlug: String) -> String {
        "submission_list_\(titleSlug)"
    }

    // MARK: - Private

    private func fileURL(for key: String) -> URL {
        // Sanitize the key to be a valid filename
        let sanitized = key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cacheDirectory.appendingPathComponent(sanitized)
    }
}
