package dev.greenfield5.app.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val LightColors = lightColorScheme(
    primary = GreenfieldGreenDark,
    onPrimary = Color.White,
    primaryContainer = GreenfieldSprout,
    onPrimaryContainer = GreenfieldInk,
    secondary = GreenfieldGreen,
    background = GreenfieldMist,
    onBackground = GreenfieldInk,
    surface = GreenfieldMist,
    onSurface = GreenfieldInk,
)

private val DarkColors = darkColorScheme(
    primary = GreenfieldSprout,
    onPrimary = GreenfieldInk,
    primaryContainer = GreenfieldGreenDark,
    onPrimaryContainer = GreenfieldMist,
    secondary = GreenfieldGreen,
    background = GreenfieldInk,
    onBackground = GreenfieldMist,
    surface = GreenfieldInk,
    onSurface = GreenfieldMist,
)

/**
 * Greenfield5 Material 3 theme: dynamic color where the OS supports it
 * (Android 12+), static fallback schemes otherwise.
 */
@Composable
fun Greenfield5Theme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }

        darkTheme -> DarkColors
        else -> LightColors
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Greenfield5Typography,
        content = content,
    )
}
