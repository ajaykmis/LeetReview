import Foundation
import CryptoKit

/// Simple disk-based cache for offline access to problems and solutions.
/// Uses the app's Caches directory with JSON-encoded files.
/// Thread-safe via actor isolation.
actor CacheManager {
    static let shared = CacheManager()

    private let cacheDirectory: URL
    private let fileManager = FileManager.default

    private init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDir.appendingPathComponent("LeetReviewCache", isDirectory: true)

        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Core Operations

    func cache(key: String, data: Data) {
        let fileURL = fileURL(for: key)
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func cache<T: Encodable>(key: String, value: T) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        cache(key: key, data: data)
    }

    func get(key: String) -> Data? {
        let fileURL = fileURL(for: key)
        return try? Data(contentsOf: fileURL)
    }

    func get<T: Decodable>(key: String, as type: T.Type) -> T? {
        guard let data = get(key: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func exists(key: String) -> Bool {
        fileManager.fileExists(atPath: fileURL(for: key).path)
    }

    func remove(key: String) {
        let fileURL = fileURL(for: key)
        try? fileManager.removeItem(at: fileURL)
    }

    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

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

    nonisolated func cacheSizeString() -> String {
        // Synchronous access for UI; uses a lightweight directory scan
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheDir = cachesDir.appendingPathComponent("LeetReviewCache", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: cacheDir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return "0 KB"
        }
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }

    // MARK: - Convenience Keys

    static func problemDetailKey(_ titleSlug: String) -> String {
        "problem_detail_\(titleSlug)"
    }

    static func submissionCodeKey(_ submissionId: String) -> String {
        "submission_code_\(submissionId)"
    }

    static func submissionListKey(_ titleSlug: String) -> String {
        "submission_list_\(titleSlug)"
    }

    // MARK: - Private

    private func fileURL(for key: String) -> URL {
        // Use SHA-256 hash as filename to prevent path traversal
        let hash = SHA256.hash(data: Data(key.utf8))
        let filename = hash.compactMap { String(format: "%02x", $0) }.joined()
        return cacheDirectory.appendingPathComponent(filename)
    }
}
