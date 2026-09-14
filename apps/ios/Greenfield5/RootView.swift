import SwiftUI

/// Root of the shell: home screen plus the Sender/Viewer entry points.
///
/// Path-based `NavigationStack` — the iOS counterpart of the Android shell's
/// state-based switching. Both shells keep this rule identical: home actions
/// map through `destination(for:)` and nothing else navigates.
struct RootView: View {
    @State private var path: [AppScreen] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView { action in
                path.append(destination(for: action))
            }
            .navigationDestination(for: AppScreen.self) { screen in
                switch screen {
                case .home:
                    // Home is the stack root; it is never pushed.
                    EmptyView()
                case .sender:
                    SenderView()
                case .viewer:
                    ViewerView()
                }
            }
        }
    }
}

#Preview {
    RootView()
}
