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
            // Only inject cookies for leetcode.com domains
            guard let host = url.host?.lowercased(),
                  host == "leetcode.com" || host.hasSuffix(".leetcode.com") else {
                webView.load(URLRequest(url: url))
                return
            }
            await injectCookies(into: webView)
            webView.load(URLRequest(url: url))
        }

        private func injectCookies(into webView: WKWebView) async {
            let store = webView.configuration.websiteDataStore.httpCookieStore

            if let session = AuthManager.getSessionCookie(),
               let cookie = HTTPCookie(properties: [
                   .domain: ".leetcode.com",
                   .path: "/",
                   .name: "LEETCODE_SESSION",
                   .value: session,
                   .secure: "TRUE",
                   .expires: Date().addingTimeInterval(60 * 60 * 24 * 30)
               ]) {
                await store.setCookie(cookie)
            }

            if let csrf = AuthManager.getCSRFToken(),
               let cookie = HTTPCookie(properties: [
                   .domain: ".leetcode.com",
                   .path: "/",
                   .name: "csrftoken",
                   .value: csrf,
                   .secure: "TRUE",
                   .expires: Date().addingTimeInterval(60 * 60 * 24 * 30)
               ]) {
                await store.setCookie(cookie)
            }
        }

        // Restrict navigation to leetcode.com domains only
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let host = navigationAction.request.url?.host?.lowercased() else {
                decisionHandler(.allow)
                return
            }
            if host == "leetcode.com" || host.hasSuffix(".leetcode.com") {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
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
