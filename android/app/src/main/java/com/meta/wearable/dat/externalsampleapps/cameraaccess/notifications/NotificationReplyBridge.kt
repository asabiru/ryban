package com.meta.wearable.dat.externalsampleapps.cameraaccess.notifications

import android.app.Notification
import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle

object NotificationReplyBridge {
    private var replyAction: Notification.Action? = null
    private var remoteInputKey: String? = null
    var lastSummary: String? = null
        private set

    @Synchronized
    fun remember(action: Notification.Action, packageName: String, title: String, text: String) {
        val remoteInput = action.remoteInputs?.firstOrNull() ?: return
        replyAction = action
        remoteInputKey = remoteInput.resultKey
        lastSummary = "$packageName — $title: $text"
    }

    @Synchronized
    fun reply(text: String): Boolean {
        val action = replyAction ?: return false
        val key = remoteInputKey ?: return false
        val intent = Intent()
        val results = Bundle().apply { putCharSequence(key, text) }
        android.app.RemoteInput.addResultsToIntent(action.remoteInputs, intent, results)
        return runCatching {
            action.actionIntent.send(null, 0, intent)
            true
        }.getOrDefault(false)
    }
}
