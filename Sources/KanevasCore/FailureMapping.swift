import Foundation

/// Whether the main frame shows Kanevas (`ok`) or the unreachable screen E-2 (`unreachable`).
public enum ConnectionState: Equatable {
    case ok
    case unreachable
}

/// Pure mapping of a navigation outcome to a `ConnectionState` (AD-reseau-1).
public enum FailureMapping {
    /// WebKit's "frame load interrupted" code: a cancelled navigation, e.g. a download or an external link.
    static let webKitFrameLoadInterrupted = 102

    /// Any `NSURLErrorDomain` error is a failure, except a cancellation; `WebKitErrorDomain` 102 is not one.
    public static func state(forError error: Error) -> ConnectionState {
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            return nsError.code == NSURLErrorCancelled ? .ok : .unreachable
        default:
            return .ok
        }
    }

    /// HTTP 500…599 is a failure; other codes (4xx pages are Kanevas' own) are not.
    public static func state(forHTTPStatus status: Int) -> ConnectionState {
        (500...599).contains(status) ? .unreachable : .ok
    }
}
