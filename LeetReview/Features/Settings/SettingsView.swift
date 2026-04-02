import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(ThemeManager.self) private var themeManager
    @Environment(StoreManager.self) private var storeManager
    @Environment(ContestReminderService.self) private var reminderService
    @State private var showingLogoutConfirmation = false
    @State private var showingClearCacheConfirmation = false
    @State private var cacheCleared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        profileCard
                        premiumCard
                        preferencesCard
                        dataCard
                        aboutCard
                        logoutButton
                    }
                    .padding(Theme.Spacing.lg)
                }
            }
            .navigationTitle("Settings")
            .toolbarColorScheme(themeManager.toolbarColorScheme, for: .navigationBar)
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.accent)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(authManager.username ?? "User")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.Colors.text)

                Text(authManager.isLoggedIn ? "Signed in with LeetCode" : "Username only mode")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Premium Card

    private var premiumCard: some View {
        VStack(spacing: 0) {
            settingSectionHeader(title: "Premium", icon: "crown.fill", tint: Theme.Colors.medium)

            if storeManager.isPurchased {
                settingRow(icon: "checkmark.seal.fill", iconColor: Theme.Colors.easy, title: "Ads Removed") {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.easy)
                }
            } else {
                Button {
                    Task { await storeManager.purchaseRemoveAds() }
                } label: {
                    settingRow(icon: "star.fill", iconColor: Theme.Colors.medium, title: "Remove Ads") {
                        if storeManager.isLoading {
                            ProgressView().controlSize(.small).tint(Theme.Colors.accent)
                        } else {
                            Text(storeManager.priceString)
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.Colors.accent)
                        }
                    }
                }
                .disabled(storeManager.isLoading)

                Divider().padding(.leading, 52)

                Button {
                    Task { await storeManager.restorePurchases() }
                } label: {
                    settingRow(icon: "arrow.clockwise", iconColor: Theme.Colors.accent, title: "Restore Purchases") {
                        EmptyView()
                    }
                }
            }

            if let error = storeManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.hard)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.md)
            }
        }
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Preferences Card

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            settingSectionHeader(title: "Preferences", icon: "paintbrush.fill", tint: Theme.Colors.accent)

            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "moon.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }

                Text("Dark Mode")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.text)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { themeManager.isDarkModeEnabled },
                    set: { themeManager.isDarkModeEnabled = $0 }
                ))
                .tint(Theme.Colors.accent)
                .labelsHidden()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider().padding(.leading, 52)

            settingRow(icon: "bell.badge", iconColor: Theme.Colors.accent, title: "Contest Reminders") {
                Picker("", selection: Binding(
                    get: { reminderService.defaultReminderMinutes },
                    set: { reminderService.defaultReminderMinutes = $0 }
                )) {
                    Text("15 min before").tag(15)
                    Text("30 min before").tag(30)
                    Text("1 hour before").tag(60)
                }
                .pickerStyle(.menu)
                .tint(Theme.Colors.accent)
            }
        }
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Data Card

    private var dataCard: some View {
        VStack(spacing: 0) {
            settingSectionHeader(title: "Data", icon: "externaldrive.fill", tint: Theme.Colors.easy)

            Button {
                showingClearCacheConfirmation = true
            } label: {
                settingRow(icon: "trash", iconColor: .orange, title: "Clear Cache") {
                    if cacheCleared {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.Colors.easy)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(CacheManager.shared.cacheSizeString())
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.background)
                            .clipShape(Capsule())
                    }
                }
            }
            .alert("Clear Cache", isPresented: $showingClearCacheConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { clearCache() }
            } message: {
                Text("This will remove all cached problem data and images.")
            }
        }
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - About Card

    private var aboutCard: some View {
        VStack(spacing: 0) {
            settingSectionHeader(title: "About", icon: "info.circle.fill", tint: Theme.Colors.textSecondary)

            settingRow(icon: "app.badge", iconColor: Theme.Colors.accent, title: "Version") {
                Text(appVersion)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Divider().padding(.leading, 52)

            NavigationLink {
                licensesView
            } label: {
                settingRow(icon: "doc.text", iconColor: Theme.Colors.accent, title: "Licenses") {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Logout Button

    private var logoutButton: some View {
        Button {
            showingLogoutConfirmation = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Colors.hard)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.hard.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .alert("Sign Out", isPresented: $showingLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) { authManager.logout() }
        } message: {
            Text("Are you sure? You will need to log in again to access your submissions.")
        }
    }

    // MARK: - Reusable Components

    private func settingSectionHeader(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private func settingRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.text)

            Spacer()

            trailing()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Licenses View

    private var licensesView: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    licenseCard(
                        name: "KeychainAccess",
                        url: "github.com/kishikawakatsumi/KeychainAccess",
                        license: "MIT License"
                    )
                    licenseCard(
                        name: "Highlightr",
                        url: "github.com/raspu/Highlightr",
                        license: "MIT License"
                    )
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .navigationTitle("Licenses")
        .toolbarColorScheme(themeManager.toolbarColorScheme, for: .navigationBar)
    }

    private func licenseCard(name: String, url: String, license: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Colors.accent.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "shippingbox")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.accent)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Colors.text)
                Text(url)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.accent)
                Text(license)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()

        Task {
            await CacheManager.shared.clearAll()
        }

        withAnimation { cacheCleared = true }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation { cacheCleared = false }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthManager())
}
