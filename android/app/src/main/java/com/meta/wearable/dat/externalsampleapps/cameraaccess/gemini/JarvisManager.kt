package com.meta.wearable.dat.externalsampleapps.cameraaccess.gemini

import android.app.Application
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.media.AudioAttributes
import android.util.Base64
import android.util.Log
import com.meta.wearable.dat.camera.StreamSession
import com.meta.wearable.dat.camera.startStreamSession
import com.meta.wearable.dat.camera.types.StreamConfiguration
import com.meta.wearable.dat.camera.types.VideoFrame
import com.meta.wearable.dat.camera.types.VideoQuality
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.SettingsManager
import com.meta.wearable.dat.externalsampleapps.cameraaccess.tools.AndroidToolRouter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.Locale
import java.util.concurrent.TimeUnit

enum class JarvisState {
    IDLE,               // Спит, ждет вызова "Джарвис"
    LISTENING_QUERY,    // Слушает вопрос пользователя
    THINKING,           // Запрашивает Gemini
    CAPTURING_FRAME,    // Включает камеру очков на 1 секунду для фото
    SPEAKING            // Озвучивает ответ в динамики очков
}

class JarvisManager(
    private val application: Application,
    private val scope: CoroutineScope
) : TextToSpeech.OnInitListener {

    companion object {
        private const val TAG = "JarvisManager"
        private const val MODEL = "gemini-3.6-flash"
        private const val SYSTEM_PROMPT =
            "Ты — Джарвис, умный персональный голосовой AI-ассистент на русском языке, встроенный в смарт-очки Ray-Ban Meta. " +
            "Ты общаешься с пользователем, когда он идет по улице или занимается делами. " +
            "Отвечай кратко, емко, дружелюбно и по делу (1-3 емких предложения на русском языке), " +
            "так как твой ответ сразу звучит в динамиках очков."

        private val VISUAL_KEYWORDS = listOf(
            "что это", "посмотри", "машин", "автомобил", "текст", "прочитай", "написано",
            "где я", "кто это", "вижу", "перед собой", "опиши", "впереди", "какой", "какая", "покажи", "глянь"
        )
    }

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(40, TimeUnit.SECONDS)
        .build()

    private var tts: TextToSpeech? = TextToSpeech(application, this, "com.google.android.tts")
    private var speechRecognizer: SpeechRecognizer? = null
    private var wakeWordEngine: VoskWakeWordEngine? = null

    private val _jarvisState = MutableStateFlow(JarvisState.IDLE)
    val jarvisState: StateFlow<JarvisState> = _jarvisState.asStateFlow()

    private val _userQuery = MutableStateFlow<String?>(null)
    val userQuery: StateFlow<String?> = _userQuery.asStateFlow()

    private val _jarvisReply = MutableStateFlow<String?>(null)
    val jarvisReply: StateFlow<String?> = _jarvisReply.asStateFlow()

    private val _lastCapturedFrame = MutableStateFlow<Bitmap?>(null)
    val lastCapturedFrame: StateFlow<Bitmap?> = _lastCapturedFrame.asStateFlow()

    private var isContinuousListening = false
    private var recognitionInProgress = false

    private val _isWakeListening = MutableStateFlow(false)
    val isWakeListening: StateFlow<Boolean> = _isWakeListening.asStateFlow()

    init {
        scope.launch(Dispatchers.Main) {
            setupSpeechRecognizer()
            wakeWordEngine = VoskWakeWordEngine(application, scope) {
                handleWakeWordDetected()
            }
            delay(1200)
            isContinuousListening = true
            startWakeWordListening()
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            val languageResult = tts?.setLanguage(Locale("ru", "RU"))
            if (languageResult == TextToSpeech.LANG_MISSING_DATA || languageResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts?.setLanguage(Locale("en", "US"))
            }
            tts?.setSpeechRate(1.05f)
            tts?.setPitch(1.0f)
        } else {
            Log.e(TAG, "Google TTS initialization failed: $status")
        }
    }

    fun speak(text: String) {
        _jarvisState.value = JarvisState.SPEAKING
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "JarvisUtterance")
        scope.launch {
            // Estimate speech duration or reset after speech
            val words = text.split(" ").size
            val waitMs = maxOf(2500L, (words * 320).toLong())
            delay(waitMs)
            if (_jarvisState.value == JarvisState.SPEAKING) {
                _jarvisState.value = JarvisState.IDLE
                if (isContinuousListening) startWakeWordListening()
            }
        }
    }

    private fun setupSpeechRecognizer() {
        if (!SpeechRecognizer.isRecognitionAvailable(application)) {
            Log.e(TAG, "SpeechRecognizer not available on device")
            return
        }

        speechRecognizer?.destroy()
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(application).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}

                override fun onError(error: Int) {
                    recognitionInProgress = false
                    if (_jarvisState.value == JarvisState.LISTENING_QUERY) {
                        _jarvisState.value = JarvisState.IDLE
                        if (isContinuousListening) startWakeWordListening()
                    }
                }

                override fun onResults(results: Bundle?) {
                    recognitionInProgress = false
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val text = matches?.firstOrNull()?.trim() ?: ""
                    handleRecognizedSpeech(text)
                }

                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
        }
    }

    fun startWakeWordListening() {
        if (!isContinuousListening || _jarvisState.value != JarvisState.IDLE) return
        _isWakeListening.value = true
        wakeWordEngine?.start()
    }

    private fun handleWakeWordDetected() {
        if (!isContinuousListening || _jarvisState.value != JarvisState.IDLE) return
        wakeWordEngine?.stop()
        _isWakeListening.value = false
        _jarvisState.value = JarvisState.LISTENING_QUERY
        tts?.speak("Слушаю", TextToSpeech.QUEUE_FLUSH, null, "JarvisPrompt")
        scope.launch {
            delay(900)
            if (isContinuousListening && _jarvisState.value == JarvisState.LISTENING_QUERY) {
                startCommandListening()
            }
        }
    }

    private fun startCommandListening() {
        if (!isContinuousListening || recognitionInProgress) return
        recognitionInProgress = true
        scope.launch(Dispatchers.Main) {
            try {
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ru-RU")
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                }
                speechRecognizer?.startListening(intent)
            } catch (e: Exception) {
                recognitionInProgress = false
                _jarvisState.value = JarvisState.IDLE
                startWakeWordListening()
            }
        }
    }

    fun stopWakeWordListening() {
        isContinuousListening = false
        _isWakeListening.value = false
        recognitionInProgress = false
        _jarvisState.value = JarvisState.IDLE
        wakeWordEngine?.stop()
        speechRecognizer?.cancel()
    }

    fun toggleWakeWordListening() {
        if (isContinuousListening) stopWakeWordListening()
        else {
            isContinuousListening = true
            startWakeWordListening()
        }
    }

    private fun handleRecognizedSpeech(recognizedText: String) {
        recognitionInProgress = false
        if (recognizedText.isBlank()) {
            _jarvisState.value = JarvisState.IDLE
            if (isContinuousListening) startWakeWordListening()
            return
        }

        Log.d(TAG, "Command recognized: $recognizedText")
        _userQuery.value = recognizedText.trim()
        processUserQuery(recognizedText.trim())
    }

    fun triggerManualQuery(query: String = "Что передо мной находится? Опиши подробно на русском языке.") {
        _userQuery.value = query
        processUserQuery(query)
    }

    private fun processUserQuery(query: String) {
        scope.launch {
            val localToolReply = AndroidToolRouter.handle(application, query)
            if (localToolReply != null) {
                _jarvisReply.value = localToolReply
                speak(localToolReply)
                return@launch
            }

            val lower = query.lowercase()
            val isVisual = VISUAL_KEYWORDS.any { lower.contains(it) }

            var frame: Bitmap? = null

            if (isVisual) {
                _jarvisState.value = JarvisState.CAPTURING_FRAME
                // Turn ON camera on-demand for 1 second, capture frame, then turn OFF immediately
                frame = captureSingleFrameFromGlasses()
                _lastCapturedFrame.value = frame
            }

            _jarvisState.value = JarvisState.THINKING
            val apiKey = SettingsManager.geminiApiKey
            val reply = callGeminiApi(frame, query, apiKey)

            _jarvisReply.value = reply
            speak(reply)
        }
    }

    /**
     * Wakes the Ray-Ban Meta glasses camera on-demand, grabs 1 frame, and immediately turns it off.
     * Saves 100% of battery between queries!
     */
    private suspend fun captureSingleFrameFromGlasses(): Bitmap? = withContext(Dispatchers.IO) {
        var capturedBitmap: Bitmap? = null
        var session: StreamSession? = null
        var frameJob: Job? = null

        try {
            session = Wearables.startStreamSession(
                application,
                AutoDeviceSelector(),
                StreamConfiguration(videoQuality = VideoQuality.HIGH, 15)
            )

            // Wait max 3.5 seconds to receive the first clean frame
            withTimeoutOrNull(3500) {
                session.videoStream.collect { videoFrame ->
                    val bmp = convertVideoFrameToBitmap(videoFrame)
                    if (bmp != null) {
                        capturedBitmap = bmp
                        return@collect
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "On-demand frame capture error", e)
        } finally {
            frameJob?.cancel()
            session?.close() // Turn off camera immediately!
            Log.d(TAG, "Glasses camera stream closed to preserve battery.")
        }

        return@withContext capturedBitmap
    }

    private fun convertVideoFrameToBitmap(videoFrame: VideoFrame): Bitmap? {
        return try {
            val buffer = videoFrame.buffer
            val dataSize = buffer.remaining()
            val byteArray = ByteArray(dataSize)

            val originalPosition = buffer.position()
            buffer.get(byteArray)
            buffer.position(originalPosition)

            val nv21 = convertI420toNV21(byteArray, videoFrame.width, videoFrame.height)
            val image = YuvImage(nv21, ImageFormat.NV21, videoFrame.width, videoFrame.height, null)
            val out = ByteArrayOutputStream().use { stream ->
                image.compressToJpeg(Rect(0, 0, videoFrame.width, videoFrame.height), 75, stream)
                stream.toByteArray()
            }

            BitmapFactory.decodeByteArray(out, 0, out.size)
        } catch (e: Exception) {
            null
        }
    }

    private fun convertI420toNV21(i420: ByteArray, width: Int, height: Int): ByteArray {
        val nv21 = ByteArray(i420.size)
        val ySize = width * height
        val uSize = ySize / 4

        System.arraycopy(i420, 0, nv21, 0, ySize)

        val uStart = ySize
        val vStart = ySize + uSize
        var nv21Index = ySize

        for (i in 0 until uSize) {
            nv21[nv21Index] = i420[vStart + i]
            nv21[nv21Index + 1] = i420[uStart + i]
            nv21Index += 2
        }

        return nv21
    }

    private suspend fun callGeminiApi(bitmap: Bitmap?, userQuery: String, apiKey: String): String = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) {
            return@withContext "Пожалуйста, введите ключ Gemini API в настройках приложения."
        }

        try {
            val url = "https://generativelanguage.googleapis.com/v1beta/models/$MODEL:generateContent?key=$apiKey"
            val partsArray = JSONArray()

            if (bitmap != null) {
                val outputStream = ByteArrayOutputStream()
                val scaled = if (bitmap.width > 1024 || bitmap.height > 1024) {
                    val scale = 1024f / maxOf(bitmap.width, bitmap.height)
                    Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true)
                } else {
                    bitmap
                }
                scaled.compress(Bitmap.CompressFormat.JPEG, 75, outputStream)
                val base64Data = Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)

                partsArray.put(JSONObject().apply {
                    put("inline_data", JSONObject().apply {
                        put("mime_type", "image/jpeg")
                        put("data", base64Data)
                    })
                })
            }

            partsArray.put(JSONObject().apply {
                put("text", userQuery)
            })

            val requestJson = JSONObject().apply {
                put("contents", JSONArray().apply {
                    put(JSONObject().apply {
                        put("role", "user")
                        put("parts", partsArray)
                    })
                })
                put("system_instruction", JSONObject().apply {
                    put("parts", JSONArray().apply {
                        put(JSONObject().apply { put("text", SYSTEM_PROMPT) })
                    })
                })
                put("generationConfig", JSONObject().apply {
                    put("temperature", 0.3)
                    put("maxOutputTokens", 200)
                })
            }

            val requestBody = requestJson.toString().toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url(url)
                .post(requestBody)
                .build()

            val response = httpClient.newCall(request).execute()
            val responseBody = response.body?.string().orEmpty()

            if (!response.isSuccessful) {
                return@withContext "Ошибка ответа AI (${response.code})"
            }

            val responseJson = JSONObject(responseBody)
            val candidates = responseJson.optJSONArray("candidates")
            val firstCandidate = candidates?.optJSONObject(0)
            val content = firstCandidate?.optJSONObject("content")
            val parts = content?.optJSONArray("parts")
            val replyText = parts?.optJSONObject(0)?.optString("text")?.trim() 
                ?: "Не удалось сформулировать ответ."

            return@withContext replyText
        } catch (e: Exception) {
            Log.e(TAG, "Gemini API failure", e)
            return@withContext "Сбой связи с сервером AI."
        }
    }

    fun release() {
        isContinuousListening = false
        _isWakeListening.value = false
        recognitionInProgress = false
        speechRecognizer?.cancel()
        wakeWordEngine?.stop()
        speechRecognizer?.destroy()
        speechRecognizer = null
        tts?.stop()
        tts?.shutdown()
        tts = null
    }
}
