package com.meta.wearable.dat.externalsampleapps.cameraaccess.notifications

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.SettingsManager

class JarvisNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        val notification = sbn.notification ?: return
        val extras = notification.extras
        val title = extras.getCharSequence("android.title")?.toString().orEmpty()
        val text = extras.getCharSequence("android.text")?.toString().orEmpty()
        if (title.isBlank() && text.isBlank()) return

        notification.actions.orEmpty().forEach { action ->
            NotificationReplyBridge.remember(action, sbn.packageName, title, text)
        }

        val summary = "$title: $text".trim(':', ' ', '\n')
        SettingsManager.saveLatestNotification(applicationContext, summary)
        if (SettingsManager.notificationReadEnabled && isReadablePackage(sbn.packageName)) {
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
