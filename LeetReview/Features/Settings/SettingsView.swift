import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ThemeManager.self) private var themeManager
    @State private var showingLogoutConfirmation = false
    @State private var showingClearCacheConfirmation = false
    @State private var cacheCleared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                List {
                    appearanceSection
                    dataSection
                    accountSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .toolbarColorScheme(themeManager.toolbarColorScheme, for: .navigationBar)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { themeManager.isDarkModeEnabled },
                set: { themeManager.isDarkModeEnabled = $0 }
            )) {
                Label {
                    Text("Dark Mode")
                        .foregroundStyle(Theme.Colors.text)
                } icon: {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .tint(Theme.Colors.accent)
            .listRowBackground(Theme.Colors.card)
        } header: {
            Text("Appearance")
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section {
            Button {
                showingClearCacheConfirmation = true
            } label: {
                Label {
                    HStack {
                        Text("Clear Cache")
                            .foregroundStyle(Theme.Colors.text)
                        Spacer()
                        if cacheCleared {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.Colors.easy)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                } icon: {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .listRowBackground(Theme.Colors.card)
            .alert("Clear Cache", isPresented: $showingClearCacheConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("This will remove all cached problem data and images. You will need an internet connection to reload them.")
            }
        } header: {
            Text("Data")
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        Section {
            Button {
                showingLogoutConfirmation = true
            } label: {
                Label {
                    Text("Logout")
                        .foregroundStyle(Theme.Colors.hard)
                } icon: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Theme.Colors.hard)
                }
            }
            .listRowBackground(Theme.Colors.card)
            .alert("Logout", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Logout", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("Are you sure you want to sign out? You will need to log in again to access your submissions.")
            }
        } header: {
            Text("Account")
                .foregroundStyle(Theme.Colors.textSecondary)
        } footer: {
            if let username = authManager.username {
                Text("Signed in as \(username)")
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Label {
                    Text("Version")
                        .foregroundStyle(Theme.Colors.text)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Theme.Colors.accent)
                }

                Spacer()

                Text(appVersion)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .listRowBackground(Theme.Colors.card)

            NavigationLink {
                licensesView
            } label: {
                Label {
                    Text("Licenses")
                        .foregroundStyle(Theme.Colors.text)
                } icon: {
                    Image(systemName: "doc.text")
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .listRowBackground(Theme.Colors.card)
        } header: {
            Text("About")
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Licenses View

    private var licensesView: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            List {
                licenseRow(
                    name: "KeychainAccess",
                    url: "https://github.com/kishikawakatsumi/KeychainAccess",
                    license: "MIT License"
                )

                licenseRow(
                    name: "Highlightr",
                    url: "https://github.com/raspu/Highlightr",
                    license: "MIT License"
                )
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Licenses")
        .toolbarColorScheme(themeManager.toolbarColorScheme, for: .navigationBar)
    }

    private func licenseRow(name: String, url: String, license: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(name)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Colors.text)

            Text(url)
                .font(.caption)
                .foregroundStyle(Theme.Colors.accent)

            Text(license)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .listRowBackground(Theme.Colors.card)
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func clearCache() {
        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()

        // Clear any temporary files
        let tmpDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(
            at: tmpDir,
            includingPropertiesForKeys: nil
        ) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }

        withAnimation {
            cacheCleared = true
        }

        // Reset the checkmark after a delay
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                cacheCleared = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AuthManager())
}
