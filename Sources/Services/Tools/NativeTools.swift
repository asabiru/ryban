import Foundation
import UIKit
import EventKit
import MediaPlayer
import UserNotifications
import CoreLocation
import Combine

// MARK: - Timer & Alarm Tool
public final class TimerTool: @unchecked Sendable {
    public static let shared = TimerTool()
    private init() {}
    
    public func setTimer(seconds: Int, label: String = "Таймер") async -> String {
        guard seconds > 0 else { return "Некорректная длительность таймера." }
        
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus != .authorized {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        
        let content = UNMutableNotificationContent()
        content.title = "⏰ \(label)"
        content.body = "Время вышло! (\(seconds / 60) мин \(seconds % 60) сек)"
        content.sound = UNNotificationSound.defaultCritical
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await center.add(request)
            let minutes = seconds / 60
            let remainingSecs = seconds % 60
            if minutes > 0 && remainingSecs > 0 {
                return "Таймер «\(label)» на \(minutes) мин \(remainingSecs) сек успешно запущен."
            } else if minutes > 0 {
                return "Таймер «\(label)» на \(minutes) мин успешно запущен."
            } else {
                return "Таймер «\(label)» на \(seconds) сек успешно запущен."
            }
        } catch {
            return "Не удалось установить таймер: \(error.localizedDescription)"
        }
    }
}

public final class AlarmTool: @unchecked Sendable {
    public static let shared = AlarmTool()
    private init() {}
    
    public func setAlarm(hour: Int, minute: Int, label: String = "Будильник", tomorrow: Bool = false) async -> String {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return "Некорректное время будильника."
        }
        
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        
        let content = UNMutableNotificationContent()
        content.title = "Будильник"
        content.body = label
        content.sound = UNNotificationSound.defaultCritical
        
        let now = Date()
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        
        if tomorrow {
            components.day = calendar.component(.day, from: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            components.month = calendar.component(.month, from: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            components.year = calendar.component(.year, from: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        do {
            try await center.add(request)
            return "Будильник «\(label)» установлен на \(String(format: "%02d:%02d", hour, minute))\(tomorrow ? " завтра" : "")."
        } catch {
            return "Не удалось установить будильник: \(error.localizedDescription)"
        }
    }
}

// MARK: - Calendar & EventKit Tool
public final class CalendarTool: @unchecked Sendable {
    public static let shared = CalendarTool()
    private let eventStore = EKEventStore()
    private init() {}
    
    public func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return (try? await eventStore.requestFullAccessToEvents()) ?? false
        } else {
            return (try? await eventStore.requestAccess(to: .event)) ?? false
        }
    }
    
    public func getEvents(daysAhead: Int = 1) async -> String {
        let hasAccess = await requestAccess()
        guard hasAccess else { return "Нет доступа к календарю. Разрешите доступ в настройках." }
        
        let startDate = Calendar.current.startOfDay(for: Date())
        guard let endDate = Calendar.current.date(byAdding: .day, value: max(1, daysAhead), to: startDate) else {
            return "Ошибка расчета даты."
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        
        if events.isEmpty {
            return "На ближайшие дни событий в календаре не запланировано."
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru-RU")
        formatter.dateFormat = "d MMMM в HH:mm"
        
        var result = "Ваши события:\n"
        for event in events {
            let timeStr = formatter.string(from: event.startDate)
            result += "• \(event.title ?? "Событие") — \(timeStr)\n"
        }
        return result
    }
    
    public func createEvent(title: String, startDate: Date, durationMinutes: Int = 60) async -> String {
        let hasAccess = await requestAccess()
        guard hasAccess else { return "Нет доступа к календарю." }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru-RU")
            formatter.dateFormat = "d MMMM в HH:mm"
            return "Событие «\(title)» добавлено на \(formatter.string(from: startDate))."
        } catch {
            return "Не удалось сохранить событие: \(error.localizedDescription)"
        }
    }
}

// MARK: - Reminders Tool
public final class RemindersTool: @unchecked Sendable {
    public static let shared = RemindersTool()
    private let eventStore = EKEventStore()
    private init() {}
    
    public func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return (try? await eventStore.requestFullAccessToReminders()) ?? false
        } else {
            return (try? await eventStore.requestAccess(to: .reminder)) ?? false
        }
    }
    
    public func addReminder(title: String, notes: String? = nil) async -> String {
        let hasAccess = await requestAccess()
        guard hasAccess else { return "Нет доступа к напоминаниям." }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        do {
            try eventStore.save(reminder, commit: true)
            return "Напоминание «\(title)» успешно сохранено."
        } catch {
            return "Не удалось сохранить напоминание: \(error.localizedDescription)"
        }
    }
}

// MARK: - Music Control Tool
public final class MusicTool: @unchecked Sendable {
    public static let shared = MusicTool()
    private let player = MPMusicPlayerController.systemMusicPlayer
    private init() {}
    
    public func control(action: String) -> String {
        let lower = action.lowercased()
        switch lower {
        case "play", "воспроизвести", "играть":
            player.play()
            return "Музыка играет."
        case "pause", "стоп", "пауза":
            player.pause()
            return "Музыка на паузе."
        case "next", "следующий", "вперед":
            player.skipToNextItem()
            return "Включен следующий трек."
        case "previous", "предыдущий", "назад":
            player.skipToPreviousItem()
            return "Включен предыдущий трек."
        default:
            return "Неизвестная команда управления плеером."
        }
    }
}

// MARK: - Communication Tool (Telegram, WhatsApp, SMS, Calls)
public final class CommunicationTool: @unchecked Sendable {
    public static let shared = CommunicationTool()
    private init() {}
    
    @MainActor
    public func sendMessage(platform: String, text: String, recipient: String? = nil) -> String {
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let plat = platform.lowercased()
        
        if plat.contains("telegram") || plat.contains("тг") {
            if let url = URL(string: "tg://msg?text=\(encodedText)") {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                    return "Открываю Telegram с текстом: «\(text)»."
                }
            }
            return "Telegram не установлен на устройстве."
        } else if plat.contains("whatsapp") || plat.contains("ватсап") {
            if let url = URL(string: "whatsapp://send?text=\(encodedText)") {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                    return "Открываю WhatsApp с текстом: «\(text)»."
                }
            }
            return "WhatsApp не установлен на устройстве."
        } else if plat.contains("sms") || plat.contains("смс") {
            let recipientStr = recipient ?? ""
            if let url = URL(string: "sms:\(recipientStr)&body=\(encodedText)") {
                UIApplication.shared.open(url)
                return "Создаю СМС: «\(text)»."
            }
        }
        
        return "Не удалось отправить сообщение через \(platform)."
    }
    
    @MainActor
    public func makeCall(phoneNumber: String) -> String {
        let cleaned = phoneNumber.filter { "0123456789+".contains($0) }
        guard let url = URL(string: "tel://\(cleaned)") else {
            return "Некорректный номер телефона."
        }
        UIApplication.shared.open(url)
        return "Набираю номер \(cleaned)..."
    }
}

// MARK: - Weather Tool (Open-Meteo Free API)
public final class WeatherTool: @unchecked Sendable {
    public static let shared = WeatherTool()
    private init() {}
    
    public func getWeather(latitude: Double = 55.7558, longitude: Double = 37.6173) async -> String {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m&timezone=auto"
        
        guard let url = URL(string: urlStr) else {
            return "Ошибка формирования запроса погоды."
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any] else {
                return "Не удалось получить данные о погоде."
            }
            
            let temp = current["temperature_2m"] as? Double ?? 0
            let feelsLike = current["apparent_temperature"] as? Double ?? temp
            let wind = current["wind_speed_10m"] as? Double ?? 0
            let precip = current["precipitation"] as? Double ?? 0
            let code = current["weather_code"] as? Int ?? 0
            
            let desc = weatherCodeDescription(code)
            
            var res = "\(desc), температура \(Int(round(temp)))°C (ощущается как \(Int(round(feelsLike)))°C), ветер \(Int(round(wind))) км/ч."
            if precip > 0 {
                res += " Осадки: \(precip) мм."
            }
            return res
        } catch {
            return "Ошибка загрузки погоды: \(error.localizedDescription)"
        }
    }
    
    private func weatherCodeDescription(_ code: Int) -> String {
        switch code {
        case 0: return "Ясно"
        case 1, 2, 3: return "Переменная облачность"
        case 45, 48: return "Туман"
        case 51, 53, 55: return "Моросящий дождь"
        case 61, 63, 65: return "Дождь"
        case 71, 73, 75: return "Снегопад"
        case 80, 81, 82: return "Ливень"
        case 95, 96, 99: return "Гроза"
        default: return "Облачно"
        }
    }
}

// MARK: - Memory & Fact Engine (Persistent Memory)
public final class MemoryTool: @unchecked Sendable {
    public static let shared = MemoryTool()
    private let defaultsKey = "agent_persistent_memories"
    
    private var memories: [String: String] {
        get {
            UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
        }
    }
    
    private init() {}
    
    public func saveMemory(key: String, value: String) -> String {
        var current = memories
        current[key] = value
        memories = current
        return "Запомнил: «\(key)» = «\(value)»."
    }
    
    public func recallMemory(query: String) -> String {
        let lower = query.lowercased()
        let current = memories
        
        let matches = current.filter { k, v in
            k.lowercased().contains(lower) || v.lowercased().contains(lower) || lower.contains(k.lowercased())
        }
        
        if matches.isEmpty {
            if current.isEmpty {
                return "В моей памяти пока ничего нет."
            }
            var all = "Вот что я помню:\n"
            for (k, v) in current.prefix(5) {
                all += "• \(k): \(v)\n"
            }
            return all
        }
        
        var res = ""
        for (k, v) in matches {
            res += "• \(k): \(v)\n"
        }
        return res
    }
    
    public func getAllMemories() -> [String: String] {
        memories
    }
}

// MARK: - Location & Places Tool
public final class LocationTool: NSObject, ObservableObject, CLLocationManagerDelegate, @unchecked Sendable {
    public static let shared = LocationTool()
    private let locationManager = CLLocationManager()
    @Published public var lastLocation: CLLocation?
    @Published public var currentCity: String = "Москва"
    
    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        self.lastLocation = loc
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            if let city = placemarks?.first?.locality {
                DispatchQueue.main.async {
                    self?.currentCity = city
                }
            }
        }
    }
    
    @MainActor
    public func openMaps(query: String) -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encoded)") {
            UIApplication.shared.open(url)
            return "Открываю карты по запросу «\(query)»."
        }
        return "Не удалось открыть карты."
    }
}
