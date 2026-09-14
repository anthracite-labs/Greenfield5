import SwiftUI

/// Viewer entry point — placeholder.
///
/// Join-code entry, sender-approval waiting state, and the incoming media
/// surface arrive with the bridge and transport follow-ups (ADR-0006).
struct ViewerView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Viewer")
                .font(.title.bold())
            Text("The incoming screen lands with the native-to-Rust bridge and the MoQ/Iroh transport work (Issue #13 follow-ups).")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .navigationTitle("Viewer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ViewerView()
    }
}
