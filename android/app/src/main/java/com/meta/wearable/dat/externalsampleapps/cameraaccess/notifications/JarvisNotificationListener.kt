package com.meta.wearable.dat.externalsampleapps.cameraaccess.notifications

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.SettingsManager

class JarvisNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        val notification = sbn.notification ?: return
        val extras = notification.extras
        val title = extras.getCharSequence("android.title")?.toString().orEmpty()
        val bigText = extras.getCharSequence("android.bigText")?.toString().orEmpty()
        val lines = extras.getCharSequenceArray("android.textLines")
            ?.joinToString(". ") { it.toString() }
            .orEmpty()
        val shortText = extras.getCharSequence("android.text")?.toString().orEmpty()
        val text = when {
            bigText.isNotBlank() -> bigText
            lines.isNotBlank() -> lines
            else -> shortText
        }
        if (title.isBlank() && text.isBlank()) return

        Log.d("JarvisNotification", "received package=${sbn.packageName} titleLength=${title.length} textLength=${text.length}")

        notification.actions.orEmpty().forEach { action ->
            NotificationReplyBridge.remember(action, sbn.packageName, title, text)
        }

        val summary = "$title: $text".trim(':', ' ', '\n')
        SettingsManager.saveLatestNotification(applicationContext, summary)
        if (SettingsManager.isNotificationReadEnabled(applicationContext) && isReadablePackage(sbn.packageName)) {
            JarvisSpeech.speak(applicationContext, summary)
        }
    }

    private fun isReadablePackage(packageName: String): Boolean {
        return packageName.contains("telegram") ||
            packageName.contains("whatsapp") ||
            packageName.contains("messenger") ||
            packageName.contains("messages")
    }
}
