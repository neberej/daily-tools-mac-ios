//
//  RedditWebView.swift
//  Reddit

import SwiftUI
import WebKit

struct RedditWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var onNavigationTitle: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = config.userContentController

        // ── 1. DOCUMENT-START: Strip subreddit CSS before it renders ──
        let earlyNuke = """
        (function() {
            // Nuke subreddit CSS as it loads into the DOM
            function isSubredditCSS(node) {
                if (node.tagName === 'LINK' && (node.rel || '').indexOf('stylesheet') !== -1) {
                    var href = (node.href || '').toLowerCase();
                    // Keep only core reddit CSS from redditstatic CDN
                    if (href.indexOf('redditstatic.com') !== -1) return false;
                    // Everything else (subreddit sheets, custom CSS) gets nuked
                    return true;
                }
                if (node.tagName === 'STYLE') {
                    var text = node.textContent || '';
                    // Our own injected style has a marker; don't remove it
                    if (text.indexOf('REDDIT_INJECT_MARKER') !== -1) return false;
                    // Small inline styles from reddit core are fine (< 200 chars)
                    if (text.length < 200) return false;
                    // Large inline styles are subreddit themes
                    return true;
                }
                return false;
            }

            var obs = new MutationObserver(function(mutations) {
                for (var i = 0; i < mutations.length; i++) {
                    var added = mutations[i].addedNodes;
                    for (var j = 0; j < added.length; j++) {
                        var n = added[j];
                        if (n.nodeType !== 1) continue;
                        if (isSubredditCSS(n)) { n.remove(); continue; }
                        // Also check children (e.g. <head> bulk insert)
                        if (n.querySelectorAll) {
                            n.querySelectorAll('link[rel="stylesheet"], style').forEach(function(child) {
                                if (isSubredditCSS(child)) child.remove();
                            });
                        }
                    }
                }
            });

            // Observe as early as possible
            function startObserving() {
                var target = document.documentElement || document;
                obs.observe(target, { childList: true, subtree: true });
            }
            if (document.documentElement) {
                startObserving();
            } else {
                new MutationObserver(function(_, self) {
                    if (document.documentElement) { self.disconnect(); startObserving(); }
                }).observe(document, { childList: true });
            }

            // Also nuke anything already present
            document.querySelectorAll('link[rel="stylesheet"], style').forEach(function(el) {
                if (isSubredditCSS(el)) el.remove();
            });
        })();
        """
        controller.addUserScript(WKUserScript(
            source: earlyNuke,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))

        // ── 2. DOCUMENT-START: Inject our dark theme CSS immediately ──
        if let css = Self.loadResource("reddit-inject", ext: "css") {
            let earlyCSS = """
            (function() {
                var style = document.createElement('style');
                style.textContent = '/* REDDIT_INJECT_MARKER */\\n' + `\(css.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`"))`;
                // Insert as first child of <html> so it's present even before <head> completes
                if (document.documentElement) {
                    document.documentElement.insertBefore(style, document.documentElement.firstChild);
                } else {
                    document.addEventListener('DOMContentLoaded', function() {
                        document.head.appendChild(style);
                    });
                }
            })();
            """
            controller.addUserScript(WKUserScript(
                source: earlyCSS,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            ))
        }

        // ── 3. DOCUMENT-START: Set viewport early ──
        let viewportScript = """
        document.addEventListener('DOMContentLoaded', function() {
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) { meta = document.createElement('meta'); meta.name = 'viewport'; document.head.appendChild(meta); }
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
        });
        """
        controller.addUserScript(WKUserScript(
            source: viewportScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        // ── 4. DOCUMENT-END: Full cleanup JS ──
        if let js = Self.loadResource("reddit-inject", ext: "js") {
            controller.addUserScript(WKUserScript(
                source: js,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            ))
        }

        // ── 5. DOCUMENT-END: Re-inject CSS at the end to ensure it wins specificity ──
        if let css = Self.loadResource("reddit-inject", ext: "css") {
            let lateCSS = """
            (function() {
                var style = document.createElement('style');
                style.textContent = '/* REDDIT_INJECT_MARKER */\\n' + `\(css.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`"))`;
                document.head.appendChild(style);
            })();
            """
            controller.addUserScript(WKUserScript(
                source: lateCSS,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            ))
        }

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
        refreshControl.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleRefresh(_:)),
            for: .valueChanged
        )
        webView.scrollView.refreshControl = refreshControl

        // Desktop user agent so old.reddit.com serves desktop layout (we restyle it ourselves)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        // ── 6. Compile content-blocker rules to block subreddit stylesheets at network level ──
        Self.compileContentRules { ruleList in
            if let ruleList = ruleList {
                webView.configuration.userContentController.add(ruleList)
            }
        }

        // Store webView reference for refresh and goBack
        context.coordinator.webView = webView

        context.coordinator.lastRequestedURL = url
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if url != context.coordinator.lastRequestedURL {
            context.coordinator.lastRequestedURL = url
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Resource Loading

    static func loadResource(_ name: String, ext: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return content
    }

    // MARK: - Content Blocker Rules

    /// Blocks subreddit CSS at the network level before it ever reaches the renderer.
    private static func compileContentRules(completion: @escaping (WKContentRuleList?) -> Void) {
        let rules = """
        [
            {
                "trigger": {
                    "url-filter": ".*/r/.+/stylesheet.*",
                    "resource-type": ["style-sheet"]
                },
                "action": { "type": "block" }
            },
            {
                "trigger": {
                    "url-filter": ".*api/subreddit_stylesheet.*",
                    "resource-type": ["style-sheet"]
                },
                "action": { "type": "block" }
            }
        ]
        """
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "RedditSubredditCSSBlocker",
            encodedContentRuleList: rules
        ) { ruleList, error in
            DispatchQueue.main.async {
                completion(ruleList)
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: RedditWebView
        var lastRequestedURL: URL?
        weak var webView: WKWebView?

        init(parent: RedditWebView) {
            self.parent = parent
        }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            webView?.reload()
            // End refreshing after navigation starts (didFinish will also fire)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                sender.endRefreshing()
            }
        }

        private static let allowedHosts = [
            "reddit.com",
            "redditmedia.com",
            "redditstatic.com",
            "redd.it",
            "reddituploads.com",
            "reddit-uploaded-media.s3-accelerate.amazonaws.com"
        ]

        private func isRedditDomain(_ host: String) -> Bool {
            let h = host.lowercased()
            return Coordinator.allowedHosts.contains(where: { h == $0 || h.hasSuffix(".\($0)") })
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false

            // Final cleanup pass: strip any subreddit CSS that slipped through,
            // and re-inject our styles on top.
            let cleanupJS = """
            (function() {
                // Remove any non-core stylesheets that snuck in
                document.querySelectorAll('link[rel="stylesheet"]').forEach(function(el) {
                    var href = (el.href || '').toLowerCase();
                    if (href.indexOf('redditstatic.com') === -1) el.remove();
                });
                // Remove large inline styles that aren't ours
                document.querySelectorAll('style').forEach(function(el) {
                    var text = el.textContent || '';
                    if (text.indexOf('REDDIT_INJECT_MARKER') === -1 && text.length > 200) el.remove();
                });
            })();
            """
            webView.evaluateJavaScript(cleanupJS, completionHandler: nil)

            // Extract subreddit name from URL for display
            if let url = webView.url {
                let path = url.path
                if let range = path.range(of: "/r/") {
                    let after = path[range.upperBound...]
                    let subreddit = after.split(separator: "/").first.map(String.init) ?? ""
                    parent.onNavigationTitle?("r/\(subreddit)")
                } else {
                    parent.onNavigationTitle?("Reddit")
                }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView,
                      decidePolicyFor navigationAction: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""
            guard scheme == "http" || scheme == "https" else {
                decisionHandler(.allow)
                return
            }

            let host = url.host?.lowercased() ?? ""

            if isRedditDomain(host) {
                // Redirect www.reddit.com / bare reddit.com → old.reddit.com
                if host == "www.reddit.com" || host == "reddit.com" {
                    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    components?.host = "old.reddit.com"
                    if let redirected = components?.url {
                        decisionHandler(.cancel)
                        webView.load(URLRequest(url: redirected))
                        return
                    }
                }
                decisionHandler(.allow)
                return
            }

            // Non-reddit links: only open externally on user tap
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
