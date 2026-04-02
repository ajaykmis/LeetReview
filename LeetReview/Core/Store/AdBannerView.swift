import SwiftUI

/// A banner ad placeholder view.
///
/// Replace the body with Google AdMob's `GADBannerView` wrapper
/// once the AdMob SDK is integrated. The view automatically hides
/// when the user has purchased "Remove Ads".
struct AdBannerView: View {
    @Environment(StoreManager.self) private var storeManager

    var body: some View {
        if storeManager.shouldShowAds {
            VStack(spacing: 4) {
                Text("Ad")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Theme.Colors.card.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
