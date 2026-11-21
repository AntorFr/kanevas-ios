import WebKit

/// The single WKNavigationDelegate (AD-socle-1). It forwards each callback to its handlers,
/// in order; later slices fill a handler and never edit this file.
final class NavigationCoordinator: NSObject, WKNavigationDelegate {
    private let handlers: [NavigationHandler]

    init(handlers: [NavigationHandler] = [NavigationPolicyHandler(), FailureHandler()]) {
        self.handlers = handlers
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        for handler in handlers {
            if let policy = handler.decidePolicy(for: navigationAction, in: webView) {
                return decisionHandler(policy)
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        for handler in handlers {
            if let policy = handler.decidePolicy(for: navigationResponse, in: webView) {
                return decisionHandler(policy)
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handlers.forEach { $0.didFail(error, in: webView) }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handlers.forEach { $0.didFail(error, in: webView) }
    }
}
