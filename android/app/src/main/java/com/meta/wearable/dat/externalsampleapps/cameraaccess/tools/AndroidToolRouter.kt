package com.meta.wearable.dat.externalsampleapps.cameraaccess.tools

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.provider.AlarmClock
import android.provider.CalendarContract
import android.telephony.PhoneNumberUtils
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.meta.wearable.dat.externalsampleapps.cameraaccess.R
import com.meta.wearable.dat.externalsampleapps.cameraaccess.notifications.NotificationReplyBridge
import com.meta.wearable.dat.externalsampleapps.cameraaccess.settings.SettingsManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlin.math.roundToInt

/**
 * Small, deterministic Android equivalent of the useful iOS native tools.
 * It handles commands locally; Gemini is used only for open-ended requests.
 */
object AndroidToolRouter {
    private const val PREFS = "jarvis_local_tools"
    private const val NOTES = "voice_notes"
    private const val MEMORIES = "memories"
    private val httpClient = OkHttpClient.Builder().callTimeout(15, TimeUnit.SECONDS).build()

    suspend fun handle(context: Context, rawText: String): String? {
        val text = rawText.trim()
        val lower = text.lowercase(Locale("ru", "RU"))

        parseNotificationCommand(context, text, lower)?.let { return it }
        parseTimer(context, lower)?.let { return it }
        parseAlarm(context, lower)?.let { return it }
        parseCalendar(context, text, lower)?.let { return it }
        parseReminder(context, text, lower)?.let { return it }
        parseNote(context, text, lower)?.let { return it }
        parseMemory(context, text, lower)?.let { return it }
        parseMusic(context, lower)?.let { return it }
        parseCall(context, text, lower)?.let { return it }
        parseMessage(context, text, lower)?.let { return it }
        parseMaps(context, text, lower)?.let { return it }
        parseSos(context, lower)?.let { return it }
        if (lower.contains("погода") || lower.contains("температур")) return weather()
        if (lower.contains("курс валют") || lower.contains("доллар") || lower.contains("евро")) return exchangeRates()
        if (lower.contains("биткоин") || lower.contains("криптовалют")) return cryptoPrices()
        if (lower.contains("раздели счет") || lower.contains("разделить счет")) {
            return splitBill(text)
        }
        if (lower == "что ты умеешь" || lower == "помощь" || lower == "команды") {
            return "Я могу поставить таймер и будильник, создать событие и напоминание, сохранить заметку или факт, управлять музыкой, позвонить, написать СМС, открыть карту, рассказать погоду и курсы валют. Для камеры скажите: «Джарвис, что передо мной?»."
        }
        return null
    }

    private fun parseNotificationCommand(context: Context, original: String, lower: String): String? {
        if (lower.contains("прочитай уведомлен") || lower.contains("какие уведомлен") || lower == "уведомления") {
            return SettingsManager.latestNotification(context)?.let { "Последнее уведомление: $it" }
                ?: "Новых уведомлений пока нет."
        }
        if (lower.contains("ответь") && (lower.contains("телеграм") || lower.contains("whatsapp") || lower.contains("сообщен"))) {
            val reply = original.substringAfter("ответь", "").trim()
            if (reply.isBlank()) return "Скажите текст ответа после слова «ответь»."
            return if (NotificationReplyBridge.reply(reply)) {
                "Ответ отправлен в последнее доступное приложение сообщений."
            } else {
                "Не нашел доступную кнопку ответа. Сначала откройте уведомление Telegram или WhatsApp."
            }
        }
        return null
    }

    private fun parseTimer(context: Context, text: String): String? {
        if (!text.contains("таймер") && !text.contains("отсчет") && !text.contains("отсчёт")) return null
        val match = Regex("(\\d+)\\s*(секунд|секунды|сек|минут|минуты|мин|час|часа)").find(text)
            ?: return "Скажите длительность, например: «Джарвис, таймер на 5 минут»."
        val value = match.groupValues[1].toLong()
        val unit = match.groupValues[2]
        val millis = when {
            unit.startsWith("час") -> value * 60 * 60 * 1000
            unit.startsWith("мин") -> value * 60 * 1000
            else -> value * 1000
        }
        if (millis <= 0 || millis > 24 * 60 * 60 * 1000L) return "Длительность таймера должна быть от секунды до 24 часов."
        scheduleNotification(context, millis, "Таймер Джарвиса", "Время вышло")
        return "Таймер запущен на $value $unit."
    }

    private fun parseAlarm(context: Context, text: String): String? {
        if (!text.contains("будильник")) return null
        val match = Regex("будильник.*?(\\d{1,2})(?::|\\s+)(\\d{2})?").find(text)
            ?: return "Скажите время, например: «Джарвис, будильник на 7:30»."
        val hour = match.groupValues[1].toIntOrNull() ?: return null
        val minute = match.groupValues[2].ifBlank { "0" }.toIntOrNull() ?: 0
        if (hour !in 0..23 || minute !in 0..59) return "Некорректное время будильника."
        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(AlarmClock.EXTRA_HOUR, hour)
            putExtra(AlarmClock.EXTRA_MINUTES, minute)
            putExtra(AlarmClock.EXTRA_MESSAGE, "Будильник Джарвиса")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        return "Открываю установку будильника на %02d:%02d.".format(hour, minute)
    }

    private fun parseCalendar(context: Context, original: String, lower: String): String? {
        if (!lower.contains("календар") && !lower.contains("событи") && !lower.contains("встреч")) return null
        val title = original.substringAfter("на ", "Встреча с Джарвисом").trim().ifBlank { "Встреча" }
        val intent = Intent(Intent.ACTION_INSERT, CalendarContract.Events.CONTENT_URI).apply {
            putExtra(CalendarContract.Events.TITLE, title)
            putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, System.currentTimeMillis() + 60 * 60 * 1000)
            putExtra(CalendarContract.EXTRA_EVENT_END_TIME, System.currentTimeMillis() + 2 * 60 * 60 * 1000)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        return "Открываю создание события «$title» в календаре."
    }

    private fun parseReminder(context: Context, original: String, lower: String): String? {
        if (!lower.contains("напомни") && !lower.contains("напоминание")) return null
        val value = original.substringAfter("что ", original.substringAfter("напомни", "")).trim()
        if (value.isBlank()) return "Скажите, о чем напомнить."
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val all = prefs.getStringSet("reminders", emptySet()).orEmpty().toMutableSet()
        all.add("${dateNow()} — $value")
        prefs.edit().putStringSet("reminders", all).apply()
        return "Напоминание сохранено: $value."
    }

    private fun parseNote(context: Context, original: String, lower: String): String? {
        if (!lower.contains("заметк") && !lower.contains("запиши") && !lower.contains("сохрани идею")) return null
        val value = original.substringAfter("что ", original.substringAfter("заметку", "")).trim()
        if (value.isBlank()) return "Скажите текст заметки."
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val notes = prefs.getStringSet(NOTES, emptySet()).orEmpty().toMutableSet()
        notes.add("${dateNow()} — $value")
        prefs.edit().putStringSet(NOTES, notes).apply()
        return "Сохранил заметку."
    }

    private fun parseMemory(context: Context, original: String, lower: String): String? {
        if (lower.contains("запомни") || lower.contains("запомнить факт")) {
            val value = original.substringAfter("запомни", "").trim().removePrefix("что ")
            if (value.isBlank()) return "Скажите, что запомнить."
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val memories = prefs.getStringSet(MEMORIES, emptySet()).orEmpty().toMutableSet()
            memories.add(value)
            prefs.edit().putStringSet(MEMORIES, memories).apply()
            return "Запомнил."
        }
        if (lower.contains("что ты помнишь") || lower.contains("моя память")) {
            val memories = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getStringSet(MEMORIES, emptySet()).orEmpty()
            return if (memories.isEmpty()) "Память пока пустая." else "Я помню: ${memories.toList().takeLast(5).joinToString("; ")}."
        }
        return null
    }

    private fun parseMusic(context: Context, text: String): String? {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val key = when {
            text.contains("следующ") || text.contains("дальше") -> android.view.KeyEvent.KEYCODE_MEDIA_NEXT
            text.contains("предыдущ") -> android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS
            text.contains("пауза") || text.contains("останови музыку") -> android.view.KeyEvent.KEYCODE_MEDIA_PAUSE
            text.contains("включи музыку") || text.contains("продолжи музыку") -> android.view.KeyEvent.KEYCODE_MEDIA_PLAY
            else -> return null
        }
        audio.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_DOWN, key))
        audio.dispatchMediaKeyEvent(android.view.KeyEvent(android.view.KeyEvent.ACTION_UP, key))
        return when (key) {
            android.view.KeyEvent.KEYCODE_MEDIA_NEXT -> "Следующий трек."
            android.view.KeyEvent.KEYCODE_MEDIA_PREVIOUS -> "Предыдущий трек."
            android.view.KeyEvent.KEYCODE_MEDIA_PAUSE -> "Музыка на паузе."
            else -> "Музыка играет."
        }
    }

    private fun parseCall(context: Context, original: String, lower: String): String? {
        if (!lower.contains("позвони") && !lower.contains("набери")) return null
        val number = Regex("[+]?\\d[\\d ()-]{6,}").find(original)?.value?.filter { it.isDigit() || it == '+' }
            ?: return "Назовите номер телефона."
        context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$number")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return "Открываю набор номера."
    }

    private fun parseMessage(context: Context, original: String, lower: String): String? {
        if (!lower.contains("отправь смс") && !lower.contains("отправь сообщение")) return null
        val number = Regex("[+]?\\d[\\d ()-]{6,}").find(original)?.value?.filter { it.isDigit() || it == '+' }
            ?: return "Назовите номер получателя."
        val body = original.substringAfter("сообщение", "").substringAfter("смс", "").trim()
        context.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$number")).apply {
            putExtra("sms_body", body)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
        return "Открываю новое сообщение для отправки."
    }

    private fun parseMaps(context: Context, original: String, lower: String): String? {
        if (!lower.contains("открой карту") && !lower.contains("найди") && !lower.contains("маршрут")) return null
        val query = original.substringAfter("найди", original.substringAfter("маршрут до", "")).trim()
        if (query.isBlank()) return "Скажите, что найти на карте."
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=${Uri.encode(query)}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return "Открываю карту по запросу «$query»."
    }

    private fun parseSos(context: Context, lower: String): String? {
        if (!lower.contains("sos") && !lower.contains("экстренн")) return null
        context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:112")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return "Открываю экстренный вызов 112."
    }

    private suspend fun weather(): String = withContext(Dispatchers.IO) {
        try {
            val response = httpClient.newCall(Request.Builder().url("https://api.open-meteo.com/v1/forecast?latitude=55.75&longitude=37.62&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m&timezone=auto").build()).execute()
            val current = JSONObject(response.body?.string().orEmpty()).getJSONObject("current")
            "Сейчас примерно ${current.getDouble("temperature_2m").roundToInt()} градусов, ощущается как ${current.getDouble("apparent_temperature").roundToInt()}, ветер ${current.getDouble("wind_speed_10m").roundToInt()} километров в час."
        } catch (_: Exception) {
            "Не удалось получить погоду."
        }
    }

    private suspend fun exchangeRates(): String = withContext(Dispatchers.IO) {
        try {
            val json = JSONObject(httpClient.newCall(Request.Builder().url("https://open.er-api.com/v6/latest/USD").build()).execute().body?.string().orEmpty())
            val rates = json.getJSONObject("rates")
            "Курс доллара примерно ${rates.getDouble("RUB").roundToInt()} рублей."
        } catch (_: Exception) { "Не удалось получить курс валют." }
    }

    private suspend fun cryptoPrices(): String = withContext(Dispatchers.IO) {
        try {
            val json = JSONObject(httpClient.newCall(Request.Builder().url("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd").build()).execute().body?.string().orEmpty())
            "Bitcoin: ${json.getJSONObject("bitcoin").getDouble("usd").roundToInt()} долларов, Ethereum: ${json.getJSONObject("ethereum").getDouble("usd").roundToInt()} долларов."
        } catch (_: Exception) { "Не удалось получить курсы криптовалют." }
    }

    private fun splitBill(original: String): String? {
        val numbers = Regex("\\d+[.,]?\\d*").findAll(original).mapNotNull { it.value.replace(',', '.').toDoubleOrNull() }.toList()
        if (numbers.size < 2) return "Скажите сумму счета и количество людей."
        val total = numbers[0]
        val people = numbers[1].toInt().coerceAtLeast(1)
        return "С каждого по ${"%.2f".format(Locale.US, total / people)}."
    }

    private fun scheduleNotification(context: Context, delayMillis: Long, title: String, body: String) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ToolAlarmReceiver::class.java).apply {
            putExtra("title", title)
            putExtra("body", body)
        }
        val pending = PendingIntent.getBroadcast(context, UUID.randomUUID().hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + delayMillis, pending)
    }

    private fun dateNow(): String = SimpleDateFormat("d MMMM HH:mm", Locale("ru", "RU")).format(Date())
}

class ToolAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val channelId = "jarvis_tools"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            notificationManager.createNotificationChannel(android.app.NotificationChannel(channelId, "Jarvis tools", android.app.NotificationManager.IMPORTANCE_HIGH))
        }
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(intent.getStringExtra("title") ?: "Джарвис")
            .setContentText(intent.getStringExtra("body") ?: "Готово")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(context).notify(System.currentTimeMillis().toInt(), notification)
        com.meta.wearable.dat.externalsampleapps.cameraaccess.notifications.JarvisSpeech.speak(
            context,
            "Таймер Джарвиса завершен. ${intent.getStringExtra("body") ?: "Время вышло"}."
        )
    }
}
