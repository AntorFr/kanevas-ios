import SwiftUI

/// E-2 (AD-reseau-3): one message and one Retry button on the system background.
struct UnreachableView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Kanevas is unreachable")
                .font(.title2)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("unreachableMessage")
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("retryButton")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
