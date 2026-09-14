package dev.greenfield5.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue

/**
 * Root of the shell: home screen plus the Sender/Viewer entry points.
 *
 * Plain state-based switching — no navigation library, because the real
 * navigation graph depends on the pairing flow, which is follow-up work
 * (Issue #13 scope).
 */
@Composable
fun Greenfield5App() {
    var screen by rememberSaveable { mutableStateOf(AppScreen.Home) }

    when (screen) {
        AppScreen.Home -> HomeScreen(
            onAction = { action -> screen = destinationFor(action) },
        )

        AppScreen.Sender -> SenderScreen(
            onBack = { screen = AppScreen.Home },
        )

        AppScreen.Viewer -> ViewerScreen(
            onBack = { screen = AppScreen.Home },
        )
    }
}
