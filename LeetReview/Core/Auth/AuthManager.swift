import Foundation
import KeychainAccess
import Observation
@preconcurrency import WebKit

@Observable
@MainActor
final class AuthManager {
    private(set) var isLoggedIn = false
    private(set) var username: String?
    private(set) var isLoading = false
    private(set) var isReadOnly = false

    var hasLeetCodeSession: Bool {
        Self.getSessionCookie() != nil
    }

    private nonisolated(unsafe) static let keychain = Keychain(service: "com.leetreview.app")
        .accessibility(.whenPasscodeSetThisDeviceOnly)
    private nonisolated static let sessionKey = "LEETCODE_SESSION"
    private nonisolated static let csrfKey = "csrftoken"
    private nonisolated static let usernameKey = "username"

    // MARK: - Session Management

    func checkSession() async {
        guard Self.getSessionCookie() != nil else {
            if let storedUsername = try? Self.keychain.get(Self.usernameKey), !storedUsername.isEmpty {
                username = storedUsername
                isLoggedIn = true
                isReadOnly = true
            } else {
                isLoggedIn = false
                username = nil
                isReadOnly = false
            }
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let status = try await LeetCodeAPI.shared.checkLoginStatus()
            if status.isSignedIn, let name = status.username {
                isLoggedIn = true
                username = name
                isReadOnly = false
                try? Self.keychain.set(name, key: Self.usernameKey)
            } else {
                clearCredentials()
            }
        } catch {
            // Network error — trust stored credentials if we have them
            if Self.getSessionCookie() != nil {
                isLoggedIn = true
                username = try? Self.keychain.get(Self.usernameKey)
                isReadOnly = false
            }
        }
    }

    func saveCredentials(session: String, csrf: String) {
        try? Self.keychain.set(session, key: Self.sessionKey)
        try? Self.keychain.set(csrf, key: Self.csrfKey)
    }

    func onLoginSuccess(session: String, csrf: String) async {
        saveCredentials(session: session, csrf: csrf)
        await checkSession()
    }

    func loginWithUsername(_ username: String) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else { return }

        try? Self.keychain.remove(Self.sessionKey)
        try? Self.keychain.remove(Self.csrfKey)
        try? Self.keychain.set(trimmedUsername, key: Self.usernameKey)
        self.username = trimmedUsername
        isLoggedIn = true
        isReadOnly = true
    }

    func logout() {
        clearCredentials()
        // Clear WebView cookies to prevent stale session
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) {}
        isLoggedIn = false
        username = nil
        isReadOnly = false
    }

    private func clearCredentials() {
        try? Self.keychain.remove(Self.sessionKey)
        try? Self.keychain.remove(Self.csrfKey)
        try? Self.keychain.remove(Self.usernameKey)
        isLoggedIn = false
        username = nil
        isReadOnly = false
    }

    // MARK: - Static Accessors (for API layer)

    nonisolated static func getSessionCookie() -> String? {
        try? keychain.get(sessionKey)
    }

    nonisolated static func getCSRFToken() -> String? {
        try? keychain.get(csrfKey)
    }

    nonisolated static func hasSessionCredentials() -> Bool {
        getSessionCookie() != nil
    }
}
