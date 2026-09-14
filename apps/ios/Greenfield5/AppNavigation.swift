import Foundation

/// The screens the shell can show (PRODUCT.md §2).
///
/// Deliberately a shell-local UI model that mirrors the Android `AppScreen`:
/// the shared session vocabulary (Role, ConnectionMode, SessionState) belongs
/// to `greenfield5-core` and crosses the seam only when the bridge lands
/// (ADR-0006). Duplicating the core model here before a real FFI boundary
/// exists would be exactly the coupling the seam is meant to prevent.
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
