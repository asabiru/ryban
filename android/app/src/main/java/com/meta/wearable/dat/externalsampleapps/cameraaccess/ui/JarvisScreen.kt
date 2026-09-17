package com.meta.wearable.dat.externalsampleapps.cameraaccess.ui

import android.app.Application
import androidx.activity.compose.LocalActivity
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicNone
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.meta.wearable.dat.externalsampleapps.cameraaccess.gemini.JarvisManager
import com.meta.wearable.dat.externalsampleapps.cameraaccess.gemini.JarvisState
import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.SettingsManager

@Composable
fun JarvisScreen(
    isRegistered: Boolean,
    hasActiveDevice: Boolean,
    onOpenSettings: () -> Unit,
    onConnectGlasses: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val application = context.applicationContext as Application
    val scope = rememberCoroutineScope()
    val jarvis = remember { JarvisManager(application, scope) }
    val state by jarvis.jarvisState.collectAsStateWithLifecycle()
    val query by jarvis.userQuery.collectAsStateWithLifecycle()
    val reply by jarvis.jarvisReply.collectAsStateWithLifecycle()

    DisposableEffect(Unit) {
        onDispose { jarvis.release() }
    }

    Box(modifier = modifier.fillMaxSize().background(Color.Black)) {
        IconButton(
            onClick = onOpenSettings,
            modifier = Modifier.align(Alignment.TopEnd).navigationBarsPadding().padding(10.dp),
        ) {
            Icon(Icons.Default.Settings, contentDescription = "Настройки", tint = Color.White)
        }

        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Icon(
                imageVector = Icons.Default.Visibility,
                contentDescription = null,
                tint = Color(0xFFBBA0FF),
                modifier = Modifier.size(72.dp),
            )
            Text(
                text = "Джарвис",
                color = Color.White,
                fontSize = 30.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 12.dp),
            )
            Text(
                text = when {
                    state == JarvisState.LISTENING_QUERY -> "Слушаю вас..."
                    state == JarvisState.THINKING -> "Думаю..."
                    state == JarvisState.CAPTURING_FRAME -> "Смотрю через камеру очков..."
                    state == JarvisState.SPEAKING -> "Отвечаю в динамики очков..."
                    isRegistered && hasActiveDevice -> "Очки подключены. Скажите: «Привет Джарвис»"
                    else -> "Подключите очки в Meta AI"
                },
                color = Color.White.copy(alpha = 0.72f),
                textAlign = TextAlign.Center,
                fontSize = 15.sp,
                modifier = Modifier.padding(top = 10.dp),
            )

            if (!isRegistered || !hasActiveDevice) {
                Button(
                    onClick = onConnectGlasses,
                    modifier = Modifier.padding(top = 24.dp),
                ) {
                    Icon(Icons.Default.Wifi, contentDescription = null)
                    Text("  Подключить очки")
                }
            }
        }

        AnimatedVisibility(
            visible = query != null || reply != null || state != JarvisState.IDLE,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.BottomCenter).padding(18.dp).navigationBarsPadding(),
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().background(Color(0xDD17121F), RoundedCornerShape(20.dp)).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = when (state) {
                        JarvisState.LISTENING_QUERY -> "🎙️ Слушаю..."
                        JarvisState.CAPTURING_FRAME -> "📷 Камера включена только для этого запроса"
                        JarvisState.THINKING -> "🧠 Анализирую..."
                        JarvisState.SPEAKING -> "🔊 Говорю в очки..."
                        else -> "💤 Готов"
                    },
                    color = Color(0xFFBBA0FF),
                    fontWeight = FontWeight.Bold,
                )
                query?.let { Text("Вы: $it", color = Color.White.copy(alpha = 0.75f), fontSize = 14.sp) }
                reply?.let { Text(it, color = Color.White, fontSize = 16.sp) }
            }
        }

        Row(
            modifier = Modifier.align(Alignment.BottomStart).navigationBarsPadding().padding(24.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            IconButton(
                onClick = { jarvis.startWakeWordListening() },
                modifier = Modifier.background(Color(0xAA332A42), RoundedCornerShape(50)),
            ) {
                Icon(
                    if (state == JarvisState.LISTENING_QUERY) Icons.Default.Mic else Icons.Default.MicNone,
                    contentDescription = "Слушать",
                    tint = if (state == JarvisState.LISTENING_QUERY) Color.Green else Color.White,
                )
            }
        }

        Button(
            onClick = { jarvis.triggerManualQuery("Что передо мной находится? Опиши подробно на русском языке.") },
            enabled = state == JarvisState.IDLE && isRegistered && hasActiveDevice,
            modifier = Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = 24.dp),
        ) {
            Icon(Icons.Default.Visibility, contentDescription = null)
            Text("  Спросить про то, что вижу")
        }
    }
}
