import Foundation

/// The screens the shell can show (PRODUCT.md §2).
///
/// Deliberately a shell-local UI model that mirrors the Android `AppScreen`:
/// navigation screens are a UI concern and stay separate from the shared
/// session vocabulary (Role, ConnectionMode, SessionState), which belongs to
/// `greenfield5-core` and reaches Swift through the UniFFI bridge (ADR-0007)
/// behind `GreenfieldRustBridge`. Conflating the two would couple navigation to
/// the session/transport boundary.
enum AppScreen: String, CaseIterable, Hashable, Sendable {
    /// Home screen with the two primary actions.
    case home
    /// Sender entry point ("Share My Screen").
    case sender
    /// Viewer entry point ("View a Screen").
    case viewer
}

/// The two primary home-screen actions (PRODUCT.md §2).
enum HomeAction: String, CaseIterable, Hashable, Sendable {
    /// "Share My Screen" — the sender entry point.
    case shareMyScreen
    /// "View a Screen" — the viewer entry point.
    case viewAScreen
}

/// Maps a home action to its destination — the shell's only navigation rule.
func destination(for action: HomeAction) -> AppScreen {
    switch action {
    case .shareMyScreen: .sender
    case .viewAScreen: .viewer
    }
}
