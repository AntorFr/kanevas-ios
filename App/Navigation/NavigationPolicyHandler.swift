import WebKit
import KanevasCore

/// Navigation policy (AD-3, AD-liens-2): allowed hosts stay in the view, anything else goes to the system.
final class NavigationPolicyHandler: NSObject, NavigationHandler, WKUIDelegate {
    private let allowedHosts: () -> Set<String>
    private let opener: URLOpening

    init(allowedHosts: @escaping () -> Set<String> = NavigationPolicyHandler.configuredHosts,
         opener: URLOpening = URLOpener.current) {
        self.allowedHosts = allowedHosts
        self.opener = opener
    }

    static func configuredHosts() -> Set<String> {
        let arguments = ProcessInfo.processInfo.arguments
        let info = Bundle.main.infoDictionary
        return NavigationPolicy.allowedHosts(arguments: arguments, infoDictionary: info,
                                             baseURL: BaseURL.resolve(arguments: arguments, infoDictionary: info))
    }

    func decidePolicy(for action: WKNavigationAction, in webView: WKWebView) -> WKNavigationActionPolicy? {
        // Sub-frames (iframes, embeds) are not link taps: leave them alone.
        guard action.targetFrame?.isMainFrame ?? true else { return nil }
        let url = action.request.url
        let isNewWindow = action.targetFrame == nil
        switch NavigationPolicy.decide(url: url, targetIsNewWindow: isNewWindow, allowedHosts: allowedHosts()) {
        case .allowInView:
            return nil
        case .loadInView:
            if let url { webView.load(URLRequest(url: url)) }
            return .cancel
        case .openExternally:
            if let url, url.scheme?.lowercased() != "about" { opener.open(url) }
            return .cancel
        }
    }

    // New-window requests: never create a second web view (AD-liens-2).
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let url = navigationAction.request.url
        switch NavigationPolicy.decide(url: url, targetIsNewWindow: true, allowedHosts: allowedHosts()) {
        case .allowInView, .loadInView:
            if let url { webView.load(URLRequest(url: url)) }
        case .openExternally:
            if let url { opener.open(url) }
        }
        return nil
    }
}
