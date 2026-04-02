import SwiftUI

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
        TabView {
            DashboardPlaceholderView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }
            ProblemsPlaceholderView()
                .tabItem { Label("Problems", systemImage: "list.bullet.rectangle.fill") }
            ReviewPlaceholderView()
                .tabItem { Label("Review", systemImage: "arrow.counterclockwise.circle.fill") }
            ProfilePlaceholderView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
            SettingsPlaceholderView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.Colors.accent)
    }
}

// MARK: - Placeholder Views (Stage 2+)

struct DashboardPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                Text("Dashboard — Coming in Stage 2")
                    .foregroundStyle(Theme.Colors.text)
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct ProblemsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                Text("Problems — Coming in Stage 2")
                    .foregroundStyle(Theme.Colors.text)
            }
            .navigationTitle("Problems")
        }
    }
}

struct ReviewPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                Text("Review — Coming in Stage 5")
                    .foregroundStyle(Theme.Colors.text)
            }
            .navigationTitle("Review")
        }
    }
}

struct ProfilePlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                Text("Profile — Coming in Stage 4")
                    .foregroundStyle(Theme.Colors.text)
            }
            .navigationTitle("Profile")
        }
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                Text("Settings — Coming in Stage 4")
                    .foregroundStyle(Theme.Colors.text)
            }
            .navigationTitle("Settings")
        }
    }
}
