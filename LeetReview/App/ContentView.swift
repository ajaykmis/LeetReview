import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            await authManager.checkSession()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                ProblemListView()
                    .tabItem { Label("Problems", systemImage: "list.bullet.rectangle.fill") }
                ReviewSessionView()
                    .tabItem { Label("Review", systemImage: "arrow.counterclockwise.circle.fill") }
                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.fill") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            .tint(Theme.Colors.accent)

            AdBannerView()
        }
    }
}
