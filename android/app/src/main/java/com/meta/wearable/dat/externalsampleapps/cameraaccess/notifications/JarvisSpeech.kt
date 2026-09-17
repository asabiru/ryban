package com.meta.wearable.dat.externalsampleapps.cameraaccess.notifications

import android.content.Context
import android.media.AudioAttributes
import android.speech.tts.TextToSpeech
import java.util.Locale

object JarvisSpeech : TextToSpeech.OnInitListener {
    private var engine: TextToSpeech? = null
    private var pendingText: String? = null

    @Synchronized
    fun speak(context: Context, text: String) {
        pendingText = text
        if (engine == null) {
            engine = TextToSpeech(context.applicationContext, this, "com.google.android.tts")
        } else {
            speakNow(text)
        }
    }

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) return
        engine?.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
        )
        engine?.setLanguage(Locale("ru", "RU"))
        pendingText?.let { speakNow(it) }
        pendingText = null
    }

    @Synchronized
    private fun speakNow(text: String) {
        engine?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "JarvisNotification")
    }
}
