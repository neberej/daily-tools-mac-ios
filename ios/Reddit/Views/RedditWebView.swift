//
//  RedditWebView.swift
//  Reddit
//
//  Minimal, stable WKWebView wrapper for a read-only Reddit reader.
//  Design principles:
//    - No redirects inside decidePolicyFor (no cancel + load pattern)
//    - Scripts inject main-frame only, once, at document-end
//    - No MutationObservers, no content blockers
//    - isLoading driven by KVO on webView.isLoading (not delegate start/finish)
//    - Navigation policy: allow reddit domains, block external (main-frame link taps only)

import SwiftUI
import WebKit

struct RedditWebView: UIViewRepresentable {
    let url: URL
    let navigationID: UUID   // changes on every explicit navigation to force load
    var onNavigationTitle: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Single CSS injection at document-end, main-frame only
        if let css = Self.loadResource("reddit-inject", ext: "css") {
            let escaped = css
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
            let script = """
            (function() {
                var s = document.createElement('style');
                s.id = 'reddit-inject-css';
                s.textContent = `\(escaped)`;
                document.head.appendChild(s);
            })();
            """
            config.userContentController.addUserScript(
                WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
        }

        // Single JS cleanup at document-end, main-frame only
        if let js = Self.loadResource("reddit-inject", ext: "js") {
            config.userContentController.addUserScript(
                WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
        }

        // Viewport meta
        let viewport = """
        (function() {
            var m = document.querySelector('meta[name="viewport"]');
            if (!m) { m = document.createElement('meta'); m.name = 'viewport'; document.head.appendChild(m); }
            m.content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
        })();
        """
        config.userContentController.addUserScript(
            WKUserScript(source: viewport, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(AppTheme.surfaceBackground)
        webView.scrollView.backgroundColor = UIColor(AppTheme.surfaceBackground)
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.allowsBackForwardNavigationGestures = true

        // Pull-to-refresh
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = UIColor(AppTheme.redditOrange)
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        // Desktop Safari UA so old.reddit.com serves desktop layout
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        // KVO: end refresh spinner when loading finishes, track URL for title
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)

        context.coordinator.webView = webView
        context.coordinator.lastNavigationID = navigationID
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if navigationID != context.coordinator.lastNavigationID {
            context.coordinator.lastNavigationID = navigationID
            webView.load(URLRequest(url: url))
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.isLoading))
        webView.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.url))
    }

    static func loadResource(_ name: String, ext: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return content
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: RedditWebView
        var lastNavigationID: UUID?
        weak var webView: WKWebView?

        private static let allowedHosts = [
            "reddit.com", "redditmedia.com", "redditstatic.com",
            "redd.it", "reddituploads.com", "imgur.com"
        ]

        init(parent: RedditWebView) {
            self.parent = parent
        }

        // MARK: KVO — end refresh spinner + track navigation title

        override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                   change: [NSKeyValueChangeKey: Any]?,
                                   context: UnsafeMutableRawPointer?) {
            guard let webView = object as? WKWebView else { return }

            if keyPath == #keyPath(WKWebView.isLoading) {
                if !webView.isLoading {
                    DispatchQueue.main.async {
                        webView.scrollView.refreshControl?.endRefreshing()
                    }
                }
            }

            if keyPath == #keyPath(WKWebView.url) {
                DispatchQueue.main.async { [weak self] in
                    guard let url = webView.url else { return }
                    let path = url.path
                    if let range = path.range(of: "/r/") {
                        let sub = path[range.upperBound...].split(separator: "/").first.map(String.init) ?? ""
                        self?.parent.onNavigationTitle?("r/\(sub)")
                    } else {
                        self?.parent.onNavigationTitle?("Reddit")
                    }
                }
            }
        }

        // MARK: Pull-to-refresh

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            guard let webView = webView, !webView.isLoading else {
                sender.endRefreshing()
                return
            }
            webView.reload()
        }

        // MARK: Navigation policy — allow/deny only, never cancel+load

        private func isAllowedDomain(_ host: String) -> Bool {
            let h = host.lowercased()
            return Coordinator.allowedHosts.contains(where: { h == $0 || h.hasSuffix(".\($0)") })
        }

        func webView(_ webView: WKWebView,
                      decidePolicyFor navigationAction: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Always allow non-HTTP (about:blank, data:, etc.)
            let scheme = url.scheme?.lowercased() ?? ""
            guard scheme == "http" || scheme == "https" else {
                decisionHandler(.allow)
                return
            }

            // Always allow subframe requests — don't interfere with iframes/embeds
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false
            if !isMainFrame {
                decisionHandler(.allow)
                return
            }

            let host = url.host?.lowercased() ?? ""

            // Allow all reddit-related domains
            if isAllowedDomain(host) {
                decisionHandler(.allow)
                return
            }

            // External link: only open externally if user tapped it
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
            } else {
                // Allow other navigations (redirects, form submissions) even to external domains
                decisionHandler(.allow)
            }
        }
    }
}
