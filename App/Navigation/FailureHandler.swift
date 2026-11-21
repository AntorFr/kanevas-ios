import WebKit
import KanevasCore

/// Failure handling (AD-4, AD-reseau-2): reports a failed main-frame navigation to the `ConnectionModel`,
/// and cancels a 5xx response so the broken page never shows.
final class FailureHandler: NavigationHandler {
    private let model: ConnectionModel?

    init(model: ConnectionModel? = nil) { self.model = model }

    func didFail(_ error: Error, in webView: WKWebView) {
        guard FailureMapping.state(forError: error) == .unreachable else { return }
        let nsError = error as NSError
        let url = (nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? webView.url
        report(.unreachable, url: url)
    }

    func decidePolicy(for response: WKNavigationResponse, in webView: WKWebView) -> WKNavigationResponsePolicy? {
        guard response.isForMainFrame,
              let http = response.response as? HTTPURLResponse,
              FailureMapping.state(forHTTPStatus: http.statusCode) == .unreachable else { return nil }
        report(.unreachable, url: http.url)
        return .cancel
    }

    private func report(_ state: ConnectionState, url: URL?) {
        DispatchQueue.main.async { [model] in
            guard let model else { return }
            if let url { model.retryURL = url }
            model.state = state
        }
    }
}
