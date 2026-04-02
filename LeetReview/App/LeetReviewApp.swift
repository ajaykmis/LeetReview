import SwiftUI
import SwiftData

@main
struct LeetReviewApp: App {
    @State private var authManager = AuthManager()
    @State private var reviewViewModel = ReviewViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .onOpenURL { url in
                    handleURLScheme(url)
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

        reviewViewModel.navigateToProblem(slug: slug)
    }
}
