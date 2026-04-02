import SwiftUI
import UserNotifications

struct ContestListView: View {
    let contests: [Contest]
    @State private var scheduledReminderIDs: Set<String> = []
    @State private var notificationDenied = false

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if contests.isEmpty {
                        Text("No upcoming contests available.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, Theme.Spacing.xl)
                    } else {
                        ForEach(contests) { contest in
                            ContestReminderCard(
                                contest: contest,
                                reminderSet: scheduledReminderIDs.contains(contest.id),
                                onToggle: { Task { await toggleReminder(for: contest) } }
                            )
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .navigationTitle("Contests")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
        .task { await loadScheduledReminders() }
        .alert("Notifications Disabled", isPresented: $notificationDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow notifications to receive contest reminders.")
        }
    }

    private func toggleReminder(for contest: Contest) async {
        if scheduledReminderIDs.contains(contest.id) {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [contest.id])
            scheduledReminderIDs.remove(contest.id)
            return
        }

        let granted = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
        guard granted == true else {
            notificationDenied = true
            return
        }

        let triggerDate = max(contest.startTime - 30 * 60, Int(Date().timeIntervalSince1970) + 5)
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: Date(timeIntervalSince1970: TimeInterval(triggerDate))
        )

        let content = UNMutableNotificationContent()
        content.title = contest.title
        content.body = "Contest starts soon."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: contest.id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        )

        try? await UNUserNotificationCenter.current().add(request)
        scheduledReminderIDs.insert(contest.id)
    }

    private func loadScheduledReminders() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        scheduledReminderIDs = Set(pending.map(\.identifier))
    }
}

private struct ContestReminderCard: View {
    let contest: Contest
    let reminderSet: Bool
    let onToggle: () -> Void

    private var startDate: Date {
        .fromTimestamp(contest.startTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(contest.title)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.text)

                    Text(startDate.dateTimeString())
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Button(action: onToggle) {
                    Label(
                        reminderSet ? "Reminder On" : "Remind Me",
                        systemImage: reminderSet ? "bell.fill" : "bell.badge"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(reminderSet ? Theme.Colors.background : Theme.Colors.accent)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(reminderSet ? Theme.Colors.accent : Theme.Colors.accent.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if let countdown = startDate.countdownString() {
                Text(countdown)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.Colors.easy)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}
