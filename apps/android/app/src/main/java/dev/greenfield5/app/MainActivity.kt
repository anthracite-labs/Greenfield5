package dev.greenfield5.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dev.greenfield5.app.ui.Greenfield5App
import dev.greenfield5.app.ui.theme.Greenfield5Theme

/**
 * Single-activity Compose host for the Greenfield5 shell.
 *
 * The shell is UI-only until the native-to-Rust bridge lands (ADR-0006
 * follow-up 1): it renders the home screen and the Sender/Viewer entry
 * points, and holds no session logic of its own — that lives in
 * `greenfield5-core` and will be reached exclusively through the seam.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            Greenfield5Theme {
                Greenfield5App()
            }
        }
    }
}
