import Foundation
import KeychainAccess
import Observation

@Observable
@MainActor
final class AuthManager {
    private(set) var isLoggedIn = false
    private(set) var username: String?
    private(set) var isLoading = false

    private nonisolated(unsafe) static let keychain = Keychain(service: "com.leetreview.app")
    private nonisolated(unsafe) static let sessionKey = "LEETCODE_SESSION"
    private nonisolated(unsafe) static let csrfKey = "csrftoken"
    private nonisolated(unsafe) static let usernameKey = "username"

    // MARK: - Session Management

    func checkSession() async {
        guard Self.getSessionCookie() != nil else {
            isLoggedIn = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let status = try await LeetCodeAPI.shared.checkLoginStatus()
            if status.isSignedIn, let name = status.username {
                isLoggedIn = true
                username = name
                try? Self.keychain.set(name, key: Self.usernameKey)
            } else {
                clearCredentials()
            }
        } catch {
            // Network error — trust stored credentials if we have them
            if Self.getSessionCookie() != nil {
                isLoggedIn = true
                username = try? Self.keychain.get(Self.usernameKey)
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

    func logout() {
        clearCredentials()
        isLoggedIn = false
        username = nil
    }

    private func clearCredentials() {
        try? Self.keychain.remove(Self.sessionKey)
        try? Self.keychain.remove(Self.csrfKey)
        try? Self.keychain.remove(Self.usernameKey)
        isLoggedIn = false
        username = nil
    }

    // MARK: - Static Accessors (for API layer)

    nonisolated static func getSessionCookie() -> String? {
        try? keychain.get(sessionKey)
    }

    nonisolated static func getCSRFToken() -> String? {
        try? keychain.get(csrfKey)
    }
}
