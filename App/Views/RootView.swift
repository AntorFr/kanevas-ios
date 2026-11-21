import SwiftUI
import KanevasCore

/// E-1: the Kanevas web view, full screen, with a native progress bar on top.
struct RootView: View {
    @StateObject private var model = WebViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            if let url = BaseURL.resolve(arguments: ProcessInfo.processInfo.arguments,
                                         infoDictionary: Bundle.main.infoDictionary) {
                WebView(url: url, model: model)
                    .ignoresSafeArea()
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-KANEVAS_FAKE_OPENER") {
                    FakeOpenerOverlay(opener: FakeURLOpener.shared)
                }
                #endif
                if model.isLoading {
                    ProgressView(value: model.progress)
                        .progressViewStyle(.linear)
                        .accessibilityIdentifier("loadingProgress")
                }
            } else {
                Text("Kanevas URL is not configured")
                    .accessibilityIdentifier("configError")
            }
        }
    }
}
