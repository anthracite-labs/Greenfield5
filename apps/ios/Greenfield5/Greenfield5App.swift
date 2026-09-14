import SwiftUI

/// Greenfield5 iOS shell entry point.
///
/// The shell is UI-only until the native-to-Rust bridge lands (ADR-0006
/// follow-up 1): it renders the home screen and the Sender/Viewer entry
/// points, and holds no session logic of its own — that lives in
/// `greenfield5-core` and will be reached exclusively through the seam.
@main
struct Greenfield5App: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
