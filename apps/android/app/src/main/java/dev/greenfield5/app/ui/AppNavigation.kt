package dev.greenfield5.app.ui

/**
 * The screens the shell can show.
 *
 * Deliberately a shell-local UI model: navigation screens are a UI concern and
 * stay separate from the shared session vocabulary (Role, ConnectionMode,
 * SessionState), which belongs to `greenfield5-core` and reaches Kotlin through
 * the UniFFI bridge (ADR-0007) behind `GreenfieldRustBridge`. Conflating the two
 * would couple navigation to the session/transport boundary.
 */
enum class AppScreen {
    /** Home screen with the two primary actions (PRODUCT.md §2). */
    Home,

    /** Sender entry point ("Share My Screen"). */
    Sender,

    /** Viewer entry point ("View a Screen"). */
    Viewer,
}

/** The two primary home-screen actions (PRODUCT.md §2). */
enum class HomeAction {
    /** "Share My Screen" — the sender entry point. */
    ShareMyScreen,

    /** "View a Screen" — the viewer entry point. */
    ViewAScreen,
}

/** Maps a home action to its destination — the shell's only navigation rule. */
fun destinationFor(action: HomeAction): AppScreen =
    when (action) {
        HomeAction.ShareMyScreen -> AppScreen.Sender
        HomeAction.ViewAScreen -> AppScreen.Viewer
    }
