import Foundation
import Observation
import UserNotifications

@Observable
@MainActor
final class ContestReminderService {
    // MARK: - State

    private(set) var scheduledContestIDs: Set<String> = []
    var notificationDenied = false

    var defaultReminderMinutes: Int {
        didSet {
            UserDefaults.standard.set(defaultReminderMinutes, forKey: Self.reminderMinutesKey)
        }
    }

    // MARK: - UserDefaults Keys

    private static let scheduledIDsKey = "contest_reminder_ids"
    private static let reminderMinutesKey = "contest_reminder_minutes"

    // MARK: - Init

    init() {
        let stored = UserDefaults.standard.object(forKey: Self.reminderMinutesKey) as? Int
        self.defaultReminderMinutes = stored ?? 30

        let savedIDs = UserDefaults.standard.stringArray(forKey: Self.scheduledIDsKey) ?? []
        self.scheduledContestIDs = Set(savedIDs)
    }

    // MARK: - Public API

    func isReminderSet(for contestTitle: String) -> Bool {
        scheduledContestIDs.contains(contestTitle)
    }

    func toggleReminder(for contest: Contest, startTime: Date) async {
        if scheduledContestIDs.contains(contest.id) {
            cancelNotification(id: contest.id)
            scheduledContestIDs.remove(contest.id)
            persistScheduledIDs()
            return
        }

        let granted = await requestPermission()
        guard granted else {
            notificationDenied = true
            return
        }

        let reminderDate = max(
            startTime.addingTimeInterval(-Double(defaultReminderMinutes) * 60),
            Date().addingTimeInterval(5)
        )

        let body = defaultReminderMinutes >= 60
            ? "Contest starts in \(defaultReminderMinutes / 60) hour\(defaultReminderMinutes / 60 > 1 ? "s" : "")."
            : "Contest starts in \(defaultReminderMinutes) minutes."

        await scheduleNotification(
            title: contest.title,
            body: body,
            date: reminderDate,
            id: contest.id
        )

        scheduledContestIDs.insert(contest.id)
        persistScheduledIDs()
    }

    func loadScheduledReminders() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let pendingIDs = Set(pending.map(\.identifier))
        // Only keep IDs that still have a pending notification
        scheduledContestIDs = scheduledContestIDs.intersection(pendingIDs)
        persistScheduledIDs()
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    func dismissDeniedAlert() {
        notificationDenied = false
    }

    // MARK: - Private

    private func scheduleNotification(title: String, body: String, date: Date, id: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification(id: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }

    private func persistScheduledIDs() {
        UserDefaults.standard.set(Array(scheduledContestIDs), forKey: Self.scheduledIDsKey)
    }
}
