package dev.greenfield5.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
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
import dev.greenfield5.app.ui.theme.Greenfield5Theme

/**
 * Sender entry point — placeholder.
 *
 * MediaProjection capture, the foreground-service lifecycle, and the
 * pairing/approval flow are platform-owned work behind the bridge and
 * transport follow-ups (ADR-0005 ownership boundaries, ADR-0006 follow-ups).
 */
@Composable
fun SenderScreen(
    onBack: () -> Unit,
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
                text = stringResource(R.string.sender_title),
                style = MaterialTheme.typography.headlineSmall,
            )
            Text(
                text = stringResource(R.string.sender_placeholder),
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
            )
            Button(onClick = onBack) {
                Text(stringResource(R.string.action_back))
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun SenderScreenPreview() {
    Greenfield5Theme {
        SenderScreen(onBack = {})
    }
}
