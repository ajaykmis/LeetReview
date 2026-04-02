import Foundation

extension Date {
    /// Returns a human-readable relative time string like "2 hours ago" or "3 days ago".
    func relativeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: .now)
    }

    /// Returns a countdown string like "2d 5h 30m" from now until this date.
    /// Returns nil if the date is in the past.
    func countdownString() -> String? {
        let now = Date.now
        guard self > now else { return nil }

        let interval = self.timeIntervalSince(now)
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Creates a Date from a Unix timestamp string (seconds since epoch).
    static func fromTimestamp(_ timestamp: String) -> Date? {
        guard let seconds = TimeInterval(timestamp) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    /// Creates a Date from a Unix timestamp integer (seconds since epoch).
    static func fromTimestamp(_ timestamp: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    /// Returns a formatted date string like "Apr 1, 2026".
    func shortDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    /// Returns a formatted date+time string like "Apr 1, 2026 at 3:00 PM".
    func dateTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
