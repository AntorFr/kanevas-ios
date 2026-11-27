import WebKit

#if DEBUG
/// Debug only (AD-session-1): the launch argument `-KANEVAS_CLEAR_SESSION` removes the cookies and website data of the
/// default data store before the first load, which simulates an expired session. Absent from Release.
enum SessionReset {
    static let argument = "-KANEVAS_CLEAR_SESSION"

    static func requested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(argument)
    }

    static func clear(then completion: @escaping () -> Void) {
        let store = WKWebsiteDataStore.default()
        store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                         modifiedSince: .distantPast) {
            completion()
        }
    }
}
#endif
