package dev.greenfield5.app.ui

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * JVM tests for the shell's only navigation rule (PRODUCT.md §2 primary
 * actions). The screens themselves are placeholders until the bridge and
 * transport work land (Issue #13 follow-ups).
 */
class AppNavigationTest {

    @Test
    fun `share my screen routes to the sender entry point`() {
        assertEquals(AppScreen.Sender, destinationFor(HomeAction.ShareMyScreen))
    }

    @Test
    fun `view a screen routes to the viewer entry point`() {
        assertEquals(AppScreen.Viewer, destinationFor(HomeAction.ViewAScreen))
    }

    @Test
    fun `every home action has a destination distinct from home`() {
        HomeAction.entries.forEach { action ->
            val destination = destinationFor(action)
            assertEquals(
                "action $action must not route back to Home",
                true,
                destination != AppScreen.Home,
            )
        }
    }

    @Test
    fun `screen model covers home and both role entry points`() {
        assertEquals(
            setOf(AppScreen.Home, AppScreen.Sender, AppScreen.Viewer),
            AppScreen.entries.toSet(),
        )
    }
}
