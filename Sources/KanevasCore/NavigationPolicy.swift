import Foundation

/// What to do with a navigation request (AD-liens-1).
public enum NavigationDecision: Equatable {
    /// A navigation inside the view, to an allowed host.
    case allowInView
    /// A new-window request (`target=_blank`, `window.open`) to an allowed host: load it in the same view.
    case loadInView
    /// Anything else: hand it to the system.
    case openExternally
}

/// Pure navigation policy (AD-3, AD-liens-1).
public enum NavigationPolicy {
    public static let launchArgumentKey = "KANEVAS_ALLOWED_HOSTS"
    public static let infoPlistKey = "KanevasAllowedHosts"

    /// Exact, case-insensitive match on the host; `https` only (`http` for a loopback host); no host: never in view.
    public static func decide(url: URL?, targetIsNewWindow: Bool, allowedHosts: Set<String>) -> NavigationDecision {
        guard let url, let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased(), !host.isEmpty else { return .openExternally }
        let allowed = Set(allowedHosts.map { $0.lowercased() })
        guard allowed.contains(host) else { return .openExternally }
        guard scheme == "https" || (scheme == "http" && isLoopback(host)) else { return .openExternally }
        return targetIsNewWindow ? .loadInView : .allowInView
    }

    /// Allowed hosts: launch argument `-KANEVAS_ALLOWED_HOSTS` (comma-separated) over Info.plist
    /// `KanevasAllowedHosts`, plus the base URL host, always (AD-liens-3).
    public static func allowedHosts(arguments: [String], infoDictionary: [String: Any]?, baseURL: URL?) -> Set<String> {
        var raw = infoDictionary?[infoPlistKey] as? String
        if let index = arguments.firstIndex(of: "-" + launchArgumentKey), arguments.indices.contains(index + 1) {
            raw = arguments[index + 1]
        }
        var hosts = Set((raw ?? "").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty })
        if let host = baseURL?.host?.lowercased(), !host.isEmpty { hosts.insert(host) }
        return hosts
    }

    static func isLoopback(_ host: String) -> Bool {
        host == "localhost" || host == "127.0.0.1" || host == "::1"
    }
}
