import SwiftUI

struct ProblemTimerView: View {
    let timer: ProblemTimer
    let onStart: () -> Void
    let onPause: () -> Void
    let onReset: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.accent)

                Text(formattedTime(timer.currentElapsed))
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Theme.Colors.text)
                    .monospacedDigit()

                Button {
                    if timer.isRunning {
                        onPause()
                    } else {
                        onStart()
                    }
                } label: {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.caption)
                        .foregroundStyle(timer.isRunning ? Theme.Colors.medium : Theme.Colors.easy)
                }
                .buttonStyle(.plain)

                Button {
                    onReset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.card)
            .clipShape(Capsule())
        }
    }

    private func formattedTime(_ totalSeconds: Double) -> String {
        let seconds = Int(totalSeconds) % 60
        let minutes = (Int(totalSeconds) / 60) % 60
        let hours = Int(totalSeconds) / 3600

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
