package com.meta.wearable.dat.externalsampleapps.cameraaccess.gemini

import android.content.Context
import android.graphics.Bitmap
import android.speech.tts.TextToSpeech
import android.util.Base64
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.Locale
import java.util.concurrent.TimeUnit

class GeminiAiService(private val context: Context) : TextToSpeech.OnInitListener {

    companion object {
        private const val TAG = "GeminiAiService"
        private const val MODEL = "gemini-2.5-flash"
        private const val DEFAULT_SYSTEM_PROMPT = 
            "Ты — русскоязычный персональный AI-ассистент в смарт-очках Ray-Ban Meta. " +
            "Ты видишь мир через камеру очков пользователя и говоришь с ним кратко, емко и по делу (1-3 предложения на русском языке), " +
            "так как твой ответ будет озвучен вслух в динамики очков."
    }

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    private var tts: TextToSpeech? = TextToSpeech(context, this)

    private val _aiResponseFlow = MutableStateFlow<String?>(null)
    val aiResponseFlow: StateFlow<String?> = _aiResponseFlow.asStateFlow()

    private val _isAnalyzingFlow = MutableStateFlow(false)
    val isAnalyzingFlow: StateFlow<Boolean> = _isAnalyzingFlow.asStateFlow()

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val result = tts?.setLanguage(Locale("ru", "RU"))
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts?.setLanguage(Locale.getDefault())
            }
            tts?.setSpeechRate(1.0f)
        }
    }

    fun speak(text: String) {
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "GeminiUtterance")
    }

    suspend fun analyzeScene(
        bitmap: Bitmap?,
        userQuestion: String = "Что передо мной находится? Опиши кратко на русском языке.",
        apiKey: String
    ): String = withContext(Dispatchers.IO) {
        if (apiKey.isBlank()) {
            val errorMsg = "Пожалуйста, укажите Gemini API ключ в настройках."
            _aiResponseFlow.value = errorMsg
            speak(errorMsg)
            return@withContext errorMsg
        }

        _isAnalyzingFlow.value = true
        try {
            val url = "https://generativelanguage.googleapis.com/v1beta/models/$MODEL:generateContent?key=$apiKey"

            val partsArray = JSONArray()

            // 1. Add visual frame if available
            if (bitmap != null) {
                val outputStream = ByteArrayOutputStream()
                val scaledBitmap = if (bitmap.width > 1024 || bitmap.height > 1024) {
                    val scale = 1024f / maxOf(bitmap.width, bitmap.height)
                    Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true)
                } else {
                    bitmap
                }
                scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 75, outputStream)
                val base64Data = Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)

                val imagePart = JSONObject().apply {
                    put("inline_data", JSONObject().apply {
                        put("mime_type", "image/jpeg")
                        put("data", base64Data)
                    })
                }
                partsArray.put(imagePart)
            }

            // 2. Add text prompt
            partsArray.put(JSONObject().apply {
                put("text", userQuestion.ifBlank { "Что передо мной находится? Опиши кратко на русском языке." })
            })

            val contentsArray = JSONArray().apply {
                put(JSONObject().apply {
                    put("role", "user")
                    put("parts", partsArray)
                })
            }

            val requestJson = JSONObject().apply {
                put("contents", contentsArray)
                put("system_instruction", JSONObject().apply {
                    put("parts", JSONArray().apply {
                        put(JSONObject().apply { put("text", DEFAULT_SYSTEM_PROMPT) })
                    })
                })
                put("generationConfig", JSONObject().apply {
                    put("temperature", 0.4)
                    put("maxOutputTokens", 250)
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
                val error = "Ошибка API (${response.code})"
                _aiResponseFlow.value = error
                speak(error)
                return@withContext error
            }

            val responseJson = JSONObject(responseBody)
            val candidates = responseJson.optJSONArray("candidates")
            val firstCandidate = candidates?.optJSONObject(0)
            val content = firstCandidate?.optJSONObject("content")
            val parts = content?.optJSONArray("parts")
            val replyText = parts?.optJSONObject(0)?.optString("text")?.trim() ?: "Не удалось распознать ответ."

            _aiResponseFlow.value = replyText
            speak(replyText)
            return@withContext replyText
        } catch (e: Exception) {
            Log.e(TAG, "Gemini call failed", e)
            val error = "Ошибка связи с AI: ${e.localizedMessage ?: "Сбой соединения"}"
            _aiResponseFlow.value = error
            speak(error)
            return@withContext error
        } finally {
            _isAnalyzingFlow.value = false
        }
    }

    fun release() {
        tts?.stop()
        tts?.shutdown()
        tts = null
    }
}
