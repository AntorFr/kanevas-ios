import Foundation

/// Resolves the Kanevas base URL (AD-5): the `-KANEVAS_URL` launch argument wins over
/// the `KanevasBaseURL` entry of Info.plist.
public enum BaseURL {
    public static let launchArgumentKey = "KANEVAS_URL"
    public static let infoPlistKey = "KanevasBaseURL"

    /// - Parameters:
    ///   - arguments: process arguments (`-KANEVAS_URL https://…` as two items).
    ///   - infoDictionary: the app's Info.plist content.
    /// - Returns: the first valid absolute http(s) URL, launch argument first; nil if none.
    public static func resolve(arguments: [String], infoDictionary: [String: Any]?) -> URL? {
        if let value = launchArgument(in: arguments), let url = parse(value) {
            return url
        }
        if let value = infoDictionary?[infoPlistKey] as? String, let url = parse(value) {
            return url
        }
        return nil
    }

    static func launchArgument(in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "-" + launchArgumentKey),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    static func parse(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else { return nil }
        return url
    }
}
