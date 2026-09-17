package com.meta.wearable.dat.externalsampleapps.cameraaccess.notifications

import android.content.Context
import android.media.AudioAttributes
import android.speech.tts.TextToSpeech
import android.util.Log
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
        val cleanText = normalize(text)
        if (cleanText.isBlank()) return
        val chunks = cleanText
            .split(Regex("(?<=[.!?;])\\s+"))
            .flatMap { part ->
                if (part.length <= 280) listOf(part) else part.chunked(280)
            }
        chunks.forEachIndexed { index, chunk ->
            engine?.speak(
                chunk,
                if (index == 0) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD,
                null,
                "JarvisNotification_$index",
            )
        }
    }

    private fun normalize(text: String): String {
        return text
            .replace(Regex("https?://\\S+"), " ссылка ")
            .replace(Regex("[@#_*|{}\\[\\]<>~=^`]+"), " ")
            .replace(Regex("[^\\p{L}\\p{N}\\p{P}\\p{Z}]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
    }
}
