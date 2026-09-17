package com.meta.wearable.dat.externalsampleapps.cameraaccess.gemini

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File

/**
 * Offline Russian keyword detector. AudioRecord stays open while the user opts into
 * wake-word mode, so Android does not repeatedly create/destroy Bluetooth audio sessions.
 */
class VoskWakeWordEngine(
    private val context: Context,
    private val scope: CoroutineScope,
    private val onWakeWord: () -> Unit,
) {
    companion object {
        private const val TAG = "VoskWakeWord"
        private const val SAMPLE_RATE = 16_000
        private const val MODEL_ASSET = "vosk-model-small-ru"
    }

    @Volatile private var running = false
    private var job: Job? = null
    private var recorder: AudioRecord? = null
    private var recognizer: Recognizer? = null

    fun start() {
        if (running) return
        running = true
        job = scope.launch(Dispatchers.IO) {
            try {
                val modelPath = copyModelIfNeeded()
                val model = Model(modelPath)
                val grammar = "[\"джарвис\", \"привет\", \"слушай\", \"[unk]\"]"
                recognizer = Recognizer(model, SAMPLE_RATE.toFloat(), grammar)

                val minimumBuffer = AudioRecord.getMinBufferSize(
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                )
                val bufferSize = maxOf(minimumBuffer * 2, SAMPLE_RATE)
                val audio = AudioRecord(
                    MediaRecorder.AudioSource.VOICE_RECOGNITION,
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize,
                )
                recorder = audio
                audio.startRecording()
                val buffer = ByteArray(bufferSize)

                while (running && isActive) {
                    val read = audio.read(buffer, 0, buffer.size)
                    if (read <= 0) continue
                    if (recognizer?.acceptWaveForm(buffer, read) == true) {
                        val text = JSONObject(recognizer?.result.orEmpty()).optString("text").lowercase()
                        if (text.contains("джарвис") || text.contains("jarvis")) {
                            withContext(Dispatchers.Main) { onWakeWord() }
                            // Wait for the owner to start a new wake session after the command.
                            break
                        }
                    }
                }
            } catch (error: Exception) {
                Log.e(TAG, "Wake-word engine stopped", error)
            } finally {
                runCatching { recorder?.stop() }
                recorder?.release()
                recorder = null
                recognizer?.close()
                recognizer = null
                running = false
            }
        }
    }

    fun stop() {
        running = false
        job?.cancel()
        job = null
        runCatching { recorder?.stop() }
    }

    private suspend fun copyModelIfNeeded(): String = withContext(Dispatchers.IO) {
        val target = File(context.filesDir, MODEL_ASSET)
        if (target.exists() && File(target, "am").exists()) return@withContext target.absolutePath
        target.deleteRecursively()
        target.mkdirs()
        copyAssetDirectory(MODEL_ASSET, target)
        target.absolutePath
    }

    private fun copyAssetDirectory(assetPath: String, target: File) {
        val children = context.assets.list(assetPath).orEmpty()
        if (children.isEmpty()) {
            context.assets.open(assetPath).use { input -> target.outputStream().use(input::copyTo) }
            return
        }
        for (child in children) {
            val childPath = "$assetPath/$child"
            val childTarget = File(target, child)
            if (context.assets.list(childPath).orEmpty().isEmpty()) {
                context.assets.open(childPath).use { input -> childTarget.outputStream().use(input::copyTo) }
            } else {
                childTarget.mkdirs()
                copyAssetDirectory(childPath, childTarget)
            }
        }
    }
}
