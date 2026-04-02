import SwiftUI
@preconcurrency import WebKit

struct AuthenticatedWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Theme.Colors.background)
        webView.scrollView.backgroundColor = UIColor(Theme.Colors.background)

        Task { @MainActor in
            await context.coordinator.load(url: url, in: webView)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        func load(url: URL, in webView: WKWebView) async {
            await injectCookies(into: webView)
            webView.load(URLRequest(url: url))
        }

        private func injectCookies(into webView: WKWebView) async {
            let store = webView.configuration.websiteDataStore.httpCookieStore

            if let session = AuthManager.getSessionCookie() {
                await store.setCookie(
                    HTTPCookie(properties: [
                        .domain: ".leetcode.com",
                        .path: "/",
                        .name: "LEETCODE_SESSION",
                        .value: session,
                        .secure: "TRUE",
                        .expires: Date().addingTimeInterval(60 * 60 * 24 * 30)
                    ])!
                )
            }

            if let csrf = AuthManager.getCSRFToken() {
                await store.setCookie(
                    HTTPCookie(properties: [
                        .domain: ".leetcode.com",
                        .path: "/",
                        .name: "csrftoken",
                        .value: csrf,
                        .secure: "TRUE",
                        .expires: Date().addingTimeInterval(60 * 60 * 24 * 30)
                    ])!
                )
            }
        }
    }
}

struct AuthenticatedBrowserPage: View {
    let title: String
    let url: URL

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            AuthenticatedWebView(url: url)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.Colors.background, for: .navigationBar)
    }
}
