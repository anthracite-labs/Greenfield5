package dev.greenfield5.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import dev.greenfield5.app.R
import dev.greenfield5.app.bridge.GreenfieldRustBridge
import dev.greenfield5.app.ui.theme.Greenfield5Theme

/**
 * The Greenfield5 home screen: the two primary actions from PRODUCT.md §2 —
 * "Share My Screen" and "View a Screen".
 */
@Composable
fun HomeScreen(
    onAction: (HomeAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(modifier = modifier) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = stringResource(R.string.home_title),
                style = MaterialTheme.typography.headlineMedium,
            )
            Text(
                text = stringResource(R.string.home_subtitle),
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
            )
            Button(
                onClick = { onAction(HomeAction.ShareMyScreen) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.action_share_my_screen))
            }
            OutlinedButton(
                onClick = { onAction(HomeAction.ViewAScreen) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.action_view_a_screen))
            }
            Text(
                text = "core ${GreenfieldRustBridge.coreVersion()} • bridge ${if (GreenfieldRustBridge.isLibraryLoaded()) "rust" else "stub"}",
                style = MaterialTheme.typography.labelSmall,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun HomeScreenPreview() {
    Greenfield5Theme {
        HomeScreen(onAction = {})
    }
}
