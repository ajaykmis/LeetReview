import SwiftUI
@preconcurrency import WebKit

struct LoginWebView: UIViewRepresentable {
    let onLoginSuccess: (String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoginSuccess: onLoginSuccess)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Theme.Colors.background)

        let url = URL(string: "https://leetcode.com/accounts/login/")!
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onLoginSuccess: (String, String) -> Void

        init(onLoginSuccess: @escaping (String, String) -> Void) {
            self.onLoginSuccess = onLoginSuccess
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            Task { @MainActor in
                await checkForAuthCookies(in: webView)
            }
        }

        private func checkForAuthCookies(in webView: WKWebView) async {
            let store = webView.configuration.websiteDataStore.httpCookieStore
            let cookies = await store.allCookies()

            let session = cookies.first(where: {
                $0.name == "LEETCODE_SESSION" && $0.domain.contains("leetcode.com")
            })?.value

            let csrf = cookies.first(where: {
                $0.name == "csrftoken" && $0.domain.contains("leetcode.com")
            })?.value

            if let session, let csrf {
                onLoginSuccess(session, csrf)
            }
        }
    }
}

// MARK: - Login View

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var showingWebView = false
    @State private var showingUsernamePrompt = false
    @State private var username = ""

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.Colors.accent)

                Text("LeetReview")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.Colors.text)

                Text("Review your LeetCode solutions\nwith spaced repetition")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    showingWebView = true
                } label: {
                    HStack {
                        Image(systemName: "person.fill")
                        Text("Sign in with LeetCode")
                    }
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.background)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Button {
                    username = authManager.username ?? ""
                    showingUsernamePrompt = true
                } label: {
                    Text("Continue with Username")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.Colors.card)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer()
                    .frame(height: 60)
            }
        }
        .sheet(isPresented: $showingWebView) {
            NavigationStack {
                LoginWebView { session, csrf in
                    showingWebView = false
                    Task {
                        await authManager.onLoginSuccess(session: session, csrf: csrf)
                    }
                }
                .navigationTitle("LeetCode Login")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingWebView = false }
                    }
                }
            }
        }
        .alert("Use LeetCode Username", isPresented: $showingUsernamePrompt) {
            TextField("Username", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Cancel", role: .cancel) {}
            Button("Continue") {
                authManager.loginWithUsername(username)
            }
        } message: {
            Text("This enables public profile, problem browsing, and contests without requiring a session cookie.")
        }
    }
}
