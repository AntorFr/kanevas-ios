import SwiftUI
import WebKit

/// Observable loading state of the web view.
final class WebViewModel: ObservableObject {
    @Published var progress: Double = 0
    @Published var isLoading = false
}

/// Full-screen WKWebView on the default (persistent) data store (AD-1).
struct WebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var model: WebViewModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator.navigation
        context.coordinator.observe(view)
        let request = URLRequest(url: url)
        #if DEBUG
        if SessionReset.requested() {
            SessionReset.clear { view.load(request) }
            return view
        }
        #endif
        view.load(request)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    final class Coordinator {
        let navigation = NavigationCoordinator()
        private let model: WebViewModel
        private var observations: [NSKeyValueObservation] = []

        init(model: WebViewModel) { self.model = model }

        func observe(_ view: WKWebView) {
            observations = [
                view.observe(\.estimatedProgress, options: [.initial, .new]) { [model] view, _ in
                    DispatchQueue.main.async { model.progress = view.estimatedProgress }
                },
                view.observe(\.isLoading, options: [.initial, .new]) { [model] view, _ in
                    DispatchQueue.main.async { model.isLoading = view.isLoading }
                },
            ]
        }
    }
}
