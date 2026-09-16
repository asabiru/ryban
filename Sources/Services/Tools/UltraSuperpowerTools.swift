import Foundation
import UIKit
import CoreLocation
import UserNotifications
import AudioToolbox
import Combine

// MARK: - 1. Anti-Lost & Distance Sentinel Tool
@MainActor
public final class AntiLostSentinelTool: ObservableObject, @unchecked Sendable {
    public static let shared = AntiLostSentinelTool()
    
    @Published public var lastKnownLocationName: String = "Не зафиксировано"
    @Published public var lastKnownTimestamp: String = "—"
    
    private let defaults = UserDefaults.standard
    private let keyLat = "anti_lost_glasses_lat"
    private let keyLon = "anti_lost_glasses_lon"
    private let keyTime = "anti_lost_glasses_time"
    
    private var wasConnected = false
    private var ignoreNextDisconnect = false
    
    private init() {
        loadSavedLocation()
        setupConnectionObserver()
    }
    
    private func setupConnectionObserver() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        WearablesManager.shared.$isConnected
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                if isConnected {
                    self.wasConnected = true
                } else if self.wasConnected && !isConnected {
                    // Unexpected disconnection -> record location & alert user!
                    self.handleUnexpectedDisconnection()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    public func markIntentionalDisconnect() {
        ignoreNextDisconnect = true
    }
    
    private func handleUnexpectedDisconnection() {
        if ignoreNextDisconnect {
            ignoreNextDisconnect = false
            wasConnected = false
            return
        }
        
        wasConnected = false
        
        let loc = LocationTool.shared.lastLocation?.coordinate
        let lat = loc?.latitude ?? 0.0
        let lon = loc?.longitude ?? 0.0
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru-RU")
        formatter.dateFormat = "d MMMM в HH:mm"
        let timeStr = formatter.string(from: Date())
        
        defaults.set(lat, forKey: keyLat)
        defaults.set(lon, forKey: keyLon)
        defaults.set(timeStr, forKey: keyTime)
        
        self.lastKnownTimestamp = timeStr
        self.lastKnownLocationName = LocationTool.shared.currentCity
        
        // Trigger loud alert & Notification on iPhone
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        
        sendLocalAlertNotification(time: timeStr)
    }
    
    private func sendLocalAlertNotification(time: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Внимание: Очки Ray-Ban отключены!"
        content.body = "Связь с очками потеряна в \(time). Проверьте, не оставили ли вы их рядом."
        content.sound = UNNotificationSound.defaultCritical
        
        let request = UNNotificationRequest(identifier: "anti_lost_alert", content: content, trigger: nil)
        center.add(request)
    }
    
    private func loadSavedLocation() {
        if let savedTime = defaults.string(forKey: keyTime) {
            self.lastKnownTimestamp = savedTime
            self.lastKnownLocationName = LocationTool.shared.currentCity
        }
    }
    
    public func getLastKnownGlassesLocation() -> String {
        let lat = defaults.double(forKey: keyLat)
        let lon = defaults.double(forKey: keyLon)
        let time = defaults.string(forKey: keyTime) ?? "недавно"
        
        if lat != 0.0 && lon != 0.0 {
            let mapsLink = "maps://?q=\(lat),\(lon)"
            if let url = URL(string: mapsLink) {
                UIApplication.shared.open(url)
            }
            return "Очки были отключены в \(time). Открываю точку на карте с последними координатами."
        }
        return "Последнее местоположение очков еще не зафиксировано."
    }
}

// MARK: - 2. Eye & Posture Health Coach Tool
@MainActor
public final class EyeAndPostureCoachTool {
    public static let shared = EyeAndPostureCoachTool()
    private init() {}
    
    public func startEyeGymnastics() -> String {
        let exercises = """
        Гимнастика для глаз (1 минута):
        1. Закройте глаза на 5 секунд и сделайте глубокий вдох.
        2. Посмотрите вдаль на самый удаленный объект за окном на 10 секунд.
        3. Сделайте 4 медленных круговых движения глазами по часовой стрелке, затем против.
        4. Быстро поморгайте 10 раз и расслабьте взгляд.
        Глаза отдохнули, можно продолжать!
        """
        VoiceSynthesisService.shared.speak(text: exercises)
        return "Инструкция по гимнастике для глаз озвучена в динамики очков."
    }
    
    public func getPostureTip() -> String {
        let tip = "Контроль осанки: расправьте плечи, потянитесь макушкой вверх и опустите подбородок на 2 сантиметра. Сделайте глубокий вдох."
        VoiceSynthesisService.shared.speak(text: tip)
        return tip
    }
}

// MARK: - 3. Speech & Pacing Coach Tool
@MainActor
public final class SpeechCoachTool {
    public static let shared = SpeechCoachTool()
    private init() {}
    
    public func analyzeSpeech(text: String, durationSeconds: Double = 30.0) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let wordCount = words.count
        let wpm = Int((Double(wordCount) / max(5.0, durationSeconds)) * 60.0)
        
        let fillerWords = ["эээ", "ммм", "ну", "типа", "как бы", "короче", "в общем", "значит", "слушай"]
        var foundFillers: [String: Int] = [:]
        
        for word in words {
            let lower = word.lowercased()
            for filler in fillerWords {
                if lower.contains(filler) {
                    foundFillers[filler, default: 0] += 1
                }
            }
        }
        
        var feedback = "Анализ речи: ваш темп ~\(wpm) слов в минуту (норма: 110–140 WPM). "
        if foundFillers.isEmpty {
            feedback += "Слов-паразитов не обнаружено! Отличная, чистая подача."
        } else {
            let list = foundFillers.map { "«\($0.key)» (\($0.value) раз)" }.joined(separator: ", ")
            feedback += "Замечены слова-паразиты: \(list). Старайтесь делать паузы вместо звуков-заполнителей."
        }
        
        return feedback
    }
}

// MARK: - 4. Bill Split Calculator Tool
public final class BillCalculatorTool: @unchecked Sendable {
    public static let shared = BillCalculatorTool()
    private init() {}
    
    public func split(total: Double, tipPercent: Double = 0, people: Int = 1) -> String {
        guard total >= 0 else { return "Сумма счета не может быть отрицательной." }
        guard people > 0 else { return "Количество человек должно быть больше нуля." }
        guard tipPercent >= 0 else { return "Процент чаевых не может быть отрицательным." }
        
        let tip = total * tipPercent / 100.0
        let grandTotal = total + tip
        let perPerson = grandTotal / Double(people)
        
        return "Счет: \(String(format: "%.2f", total)), чаевые \(String(format: "%.2f", tip)) (\(String(format: "%.1f", tipPercent))%), итого \(String(format: "%.2f", grandTotal)). На каждого из \(people): \(String(format: "%.2f", perPerson))."
    }
}

// MARK: - 5. Photo Director Tool
@MainActor
public final class PhotoDirectorTool: @unchecked Sendable {
    public static let shared = PhotoDirectorTool()
    private init() {}
    
    public func directPhotoComposition() async -> String {
        guard let frame = WearablesManager.shared.latestFrame else {
            return "Камера очков не передает кадр."
        }
        
        do {
            let advice = try await GeminiService.shared.generateResponse(
                image: frame,
                prompt: "Оцени ракурс, освещение и композицию в кадре. Дай короткую подсказку (1-2 предложения), как скорректировать положение головы или света для идеального кадра.",
                apiKey: AppState.shared.apiKey,
                model: AppState.shared.selectedModel,
                systemPrompt: "Ты — профессиональный фоторежиссер. Давай четкие и полезные советы по ракурсу."
            )
            return "Совет фоторежиссера: \(advice)"
        } catch {
            return "Ракурс хороший, можно делать снимок!"
        }
    }
}

// MARK: - 5. Offline Fallback Command Engine
public final class OfflineCommandEngine: @unchecked Sendable {
    public static let shared = OfflineCommandEngine()
    private init() {}
    
    @MainActor
    public func handleOfflineCommand(query: String) -> (handled: Bool, response: String) {
        let lower = query.lowercased()
        
        // 1. Time query
        if lower.contains("сколько время") || lower.contains("который час") || lower.contains("время") {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru-RU")
            formatter.dateFormat = "HH:mm"
            let timeStr = formatter.string(from: Date())
            return (true, "Сейчас \(timeStr).")
        }
        
        // 2. Music playback
        if lower.contains("следующий трек") || lower.contains("след трек") {
            return (true, MusicTool.shared.control(action: "next"))
        }
        if lower.contains("пауза") || lower.contains("стоп музыка") {
            return (true, MusicTool.shared.control(action: "pause"))
        }
        if lower.contains("включи музыку") || lower.contains("играть") {
            return (true, MusicTool.shared.control(action: "play"))
        }
        
        // 3. Find phone
        if lower.contains("где телефон") || lower.contains("найди телефон") {
            return (true, FindMyPhoneTool.shared.triggerFindPhoneAlarm())
        }
        
        // 4. Memory cleaner
        if lower.contains("очисти память") || lower.contains("очисти кэш") {
            let res = GlassesStorageManager.shared.clearMemoryAndCache()
            return (true, res.message)
        }
        
        return (false, "")
    }
}

// MARK: - 6. Interactive City Trivia Tool
@MainActor
public final class CityTriviaTool: @unchecked Sendable {
    public static let shared = CityTriviaTool()
    private init() {}
    
    public func startCityTrivia() async -> String {
        let city = LocationTool.shared.currentCity
        let prompt = "Придумай один интересный короткий факт-загадку или квиз-вопрос про город \(city) или архитектуру вокруг (1-2 предложения с вопросом в конце)."
        
        do {
            let question = try await GeminiService.shared.generateResponse(
                image: WearablesManager.shared.latestFrame,
                prompt: prompt,
                apiKey: AppState.shared.apiKey,
                model: AppState.shared.selectedModel,
                systemPrompt: "Ты — веселый гид и ведущий квизов на прогулке."
            )
            return "🎮 Городской квиз: \(question)"
        } catch {
            return "Готовы к викторине? Знаете ли вы, какое самое старое здание в этом районе?"
        }
    }
}
