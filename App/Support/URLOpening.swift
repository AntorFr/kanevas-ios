import SwiftUI

/// Opens a URL outside the shell (AD-liens-4).
protocol URLOpening: AnyObject {
    func open(_ url: URL)
}

final class SystemURLOpener: URLOpening {
    func open(_ url: URL) { UIApplication.shared.open(url) }
}

#if DEBUG
/// Test double (`-KANEVAS_FAKE_OPENER`): records the opened URLs instead of leaving the app.
final class FakeURLOpener: ObservableObject, URLOpening {
    static let shared = FakeURLOpener()
    @Published private(set) var count = 0
    @Published private(set) var lastURL = ""

    func open(_ url: URL) {
        DispatchQueue.main.async {
            self.count += 1
            self.lastURL = url.absoluteString
        }
    }
}

/// Hidden overlay read by the UI tests; absent from Release.
struct FakeOpenerOverlay: View {
    @ObservedObject var opener: FakeURLOpener
    var body: some View {
        VStack {
            Text("\(opener.count)").accessibilityIdentifier("externalOpenCount")
            Text(opener.lastURL).accessibilityIdentifier("lastExternalURL")
        }
        .font(.system(size: 1)).opacity(0.01).allowsHitTesting(false)
    }
}
#endif

enum URLOpener {
    static var current: URLOpening {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-KANEVAS_FAKE_OPENER") { return FakeURLOpener.shared }
        #endif
        return systemOpener
    }
    private static let systemOpener = SystemURLOpener()
}
