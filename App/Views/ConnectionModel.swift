import Foundation
import KanevasCore

/// Connection state of the main frame (AD-reseau-2), written by `FailureHandler`, read by `RootView` (E-2).
final class ConnectionModel: ObservableObject {
    @Published var state: ConnectionState = .ok
    /// The last address that failed; nil before any failure.
    var retryURL: URL?
    /// Set by `WebView`: loads an address with `load(URLRequest)`.
    var loadURL: ((URL) -> Void)?

    /// Retry (AD-reseau-3): hides E-2, then reloads the failed address, else `baseURL`.
    func retry(baseURL: URL) {
        state = .ok
        loadURL?(retryURL ?? baseURL)
    }
}
