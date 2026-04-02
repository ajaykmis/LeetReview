import SwiftUI
import SwiftData
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct LeetReviewApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authManager = AuthManager()
    @State private var themeManager = ThemeManager()
    @State private var reviewViewModel = ReviewViewModel()
    @State private var storeManager = StoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(themeManager)
                .environment(storeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
                .onOpenURL { url in
                    handleURLScheme(url)
                }
                .task {
                    storeManager.startIfNeeded()
                }
        }
        .modelContainer(for: ReviewItem.self)
    }

    // MARK: - URL Scheme Handler

    /// Handles `leetreview://problem/{slug}` URLs.
    /// This allows deep-linking from Anki cards or other apps directly to a review item.
    private func handleURLScheme(_ url: URL) {
        guard url.scheme == "leetreview" else { return }
        guard url.host == "problem" else { return }

        // Extract slug from path: leetreview://problem/{slug}
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let slug = pathComponents.first, !slug.isEmpty else { return }

        // Validate slug: only allow lowercase alphanumeric and hyphens
        guard slug.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil else { return }

        reviewViewModel.navigateToProblem(slug: slug)
    }
}
