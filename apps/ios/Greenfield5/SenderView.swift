import SwiftUI

/// Sender entry point — placeholder.
///
/// ReplayKit broadcast upload extension, capture consent, and the
/// pairing/approval flow are platform-owned work behind the bridge and
/// transport follow-ups (ADR-0005 ownership boundaries, ADR-0006
/// follow-ups — including the iOS 27 RPBroadcast deprecation question).
struct SenderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Sender")
                .font(.title.bold())
            Text("Screen capture lands with the native-to-Rust bridge and the MoQ/Iroh transport work (Issue #13 follow-ups).")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .navigationTitle("Sender")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SenderView()
    }
}
