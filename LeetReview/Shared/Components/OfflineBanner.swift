import SwiftUI

/// A compact banner that appears when the device is offline.
/// Shows a wifi.slash icon with an informational message.
struct OfflineBanner: View {
    @Environment(OfflineManager.self) private var offlineManager

    var body: some View {
        if offlineManager.isOffline {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "wifi.slash")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.Colors.medium)

                Text("You're offline \u{2014} showing cached data")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.text)

                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.medium.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }
}
