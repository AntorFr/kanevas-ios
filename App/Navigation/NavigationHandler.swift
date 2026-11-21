import WebKit

/// One concern of the navigation delegate. Every method has a pass-through default,
/// so a handler implements only what its slice needs.
protocol NavigationHandler: AnyObject {
    /// Return nil to leave the decision to the next handler.
    func decidePolicy(for action: WKNavigationAction, in webView: WKWebView) -> WKNavigationActionPolicy?
    func didFail(_ error: Error, in webView: WKWebView)
    func decidePolicy(for response: WKNavigationResponse, in webView: WKWebView) -> WKNavigationResponsePolicy?
}

extension NavigationHandler {
    func decidePolicy(for action: WKNavigationAction, in webView: WKWebView) -> WKNavigationActionPolicy? { nil }
    func didFail(_ error: Error, in webView: WKWebView) {}
    func decidePolicy(for response: WKNavigationResponse, in webView: WKWebView) -> WKNavigationResponsePolicy? { nil }
}
