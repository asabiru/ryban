package com.meta.wearable.dat.externalsampleapps.cameraaccess.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.IntelligenceEngine
import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.SettingsManager

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var apiKey by remember { mutableStateOf(SettingsManager.geminiApiKey) }
    var engine by remember { mutableStateOf(SettingsManager.intelligenceEngine) }

    BackHandler { onBack() }

    Column(modifier = modifier.fillMaxSize()) {
        TopAppBar(
            title = { Text("Джарвис — настройки") },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Назад")
                }
            },
        )
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Text("Очки", style = MaterialTheme.typography.titleMedium)
            Text(
                "Камера очков включается только по запросу Джарвиса и закрывается сразу после снимка.",
                style = MaterialTheme.typography.bodyMedium,
            )

            Text("AI-модель", style = MaterialTheme.typography.titleMedium)
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                IntelligenceEngine.entries.forEachIndexed { index, value ->
                    SegmentedButton(
                        selected = engine == value,
                        onClick = {
                            engine = value
                            SettingsManager.intelligenceEngine = value
                        },
                        shape = SegmentedButtonDefaults.itemShape(index, IntelligenceEngine.entries.size),
                    ) { Text(value.label) }
                }
            }

            Text("Gemini API", style = MaterialTheme.typography.titleMedium)
            OutlinedTextField(
                value = apiKey,
                onValueChange = {
                    apiKey = it
                    SettingsManager.geminiApiKey = it
                },
                label = { Text("Gemini API key") },
                placeholder = { Text("AIzaSy…") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Text(
                "Ключ хранится только локально на телефоне и нужен для ответов Gemini.",
                style = MaterialTheme.typography.bodySmall,
            )

            Button(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
                Text("Готово")
            }
            TextButton(onClick = {
                SettingsManager.geminiApiKey = ""
                apiKey = ""
            }) {
                Text("Удалить API key")
            }
        }
    }
}
