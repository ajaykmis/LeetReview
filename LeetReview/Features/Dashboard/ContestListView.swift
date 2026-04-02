import SwiftUI

struct ContestListView: View {
    let contests: [Contest]
    @Environment(ContestReminderService.self) private var reminderService

    var body: some View {
        @Bindable var service = reminderService

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
                                reminderSet: reminderService.isReminderSet(for: contest.id),
                                onToggle: {
                                    Task {
                                        let startTime = Date.fromTimestamp(contest.startTime)
                                        await reminderService.toggleReminder(for: contest, startTime: startTime)
                                    }
                                }
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
        .task { await reminderService.loadScheduledReminders() }
        .alert("Notifications Disabled", isPresented: $service.notificationDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow notifications to receive contest reminders.")
        }
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
