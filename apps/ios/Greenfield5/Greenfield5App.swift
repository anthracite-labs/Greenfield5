import SwiftUI

/// Greenfield5 iOS shell entry point.
///
/// The shell renders the home screen and the Sender/Viewer entry points and
/// holds no session logic of its own — that lives in `greenfield5-core` and is
/// reached through the UniFFI bridge (`GreenfieldRustBridge`, ADR-0007).
/// Pairing, capture and transport flows are follow-up work.
@main
struct Greenfield5App: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
