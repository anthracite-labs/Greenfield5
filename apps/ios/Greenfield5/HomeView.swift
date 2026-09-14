import SwiftUI

/// The Greenfield5 home screen: the two primary actions from PRODUCT.md §2 —
/// "Share My Screen" and "View a Screen".
struct HomeView: View {
    let onAction: (HomeAction) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Greenfield5")
                .font(.largeTitle.bold())
            Text("One sender. One viewer. You stay in control.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Share My Screen") {
                onAction(.shareMyScreen)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            Button("View a Screen") {
                onAction(.viewAScreen)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            Text("core \(GreenfieldRustBridge.getCoreVersion()) • bridge \(GreenfieldRustBridge.isRustLibraryPresent() ? "rust" : "stub")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

#Preview {
    HomeView(onAction: { _ in })
}
