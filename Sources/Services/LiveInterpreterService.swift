import Foundation
import AVFoundation
import UIKit
import Combine

public enum TranslationDirection: String {
    case foreignToRussian = "foreign_to_russian"
    case russianToForeign = "russian_to_foreign"
}

public struct TranslationTurn: Identifiable {
    public let id = UUID()
    public let timestamp = Date()
    public let originalText: String
    public let translatedText: String
    public let direction: TranslationDirection
    public let language: String
}

@MainActor
public final class LiveInterpreterService: ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = LiveInterpreterService()
    
    @Published public var isActive: Bool = false
    @Published public var selectedForeignLanguage: String = "Английский"
    @Published public var turns: [TranslationTurn] = []
    @Published public var currentOriginal: String = ""
    @Published public var currentTranslation: String = ""
    @Published public var statusMessage: String = "Переводчик выключен"
    
    public let availableLanguages = [
        "Английский",
        "Испанский",
        "Китайский",
        "Немецкий",
        "Французский",
        "Турецкий",
        "Итальянский",
        "Арабский",
        "Японский",
        "Корейский"
    ]
    
    private let speech = SpeechRecognitionService.shared
    private let tts = VoiceSynthesisService.shared
    private let foreignSynthesizer = AVSpeechSynthesizer()
    private var expectedDirection: TranslationDirection = .russianToForeign
    private var foreignSpeechCompletion: (() -> Void)?
    
    private init() {
        foreignSynthesizer.delegate = self
    }
    
    public func startInterpreter(foreignLanguage: String = "Английский") {
        self.selectedForeignLanguage = foreignLanguage
        self.expectedDirection = .russianToForeign
        self.isActive = true
        self.statusMessage = "Синхронный переводчик активен (\(foreignLanguage))"
        
        // Notify user via glasses
        tts.speak(text: "Режим переводчика активирован. Я перевожу ваш диалог с \(foreignLanguage.lowercased()) языка. Говорите.") { [weak self] in
            self?.listenForNextTurn()
        }
    }
    
    public func stopInterpreter() {
        self.isActive = false
        self.statusMessage = "Переводчик остановлен"
        speech.stopListening()
        tts.stop()
        if foreignSynthesizer.isSpeaking {
            foreignSynthesizer.stopSpeaking(at: .immediate)
        }
        foreignSpeechCompletion = nil
        
        tts.speak(text: "Режим синхронного перевода завершен.")
    }
    
    public func toggleInterpreter() {
        if isActive {
            stopInterpreter()
        } else {
            startInterpreter(foreignLanguage: selectedForeignLanguage)
        }
    }
    
    private func listenForNextTurn() {
        guard isActive else { return }
        
        let localeIdentifier = expectedDirection == .russianToForeign
            ? "ru-RU"
            : voiceCodeForLanguage(selectedForeignLanguage)
        
        do {
            try speech.startListening(localeIdentifier: localeIdentifier, autoStopOnSilence: true, onPartialResult: { [weak self] partial in
                self?.currentOriginal = partial
            }, onFinalResult: { [weak self] finalPhrase in
                guard let self = self else { return }
                self.currentOriginal = finalPhrase
                Task {
                    await self.processTranslation(text: finalPhrase)
                }
            })
        } catch {
            statusMessage = "Ошибка микрофона: \(error.localizedDescription)"
        }
    }
    
    private func processTranslation(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            listenForNextTurn()
            return
        }
        
        // Check for exit commands
        let lower = trimmed.lowercased()
        if lower.contains("стоп перевод") || lower.contains("заверши перевод") || lower.contains("выключи перевод") || lower.contains("хватит переводить") {
            stopInterpreter()
            return
        }
        
        statusMessage = "Перевожу..."
        
        let apiKey = AppState.shared.apiKey
        let model = AppState.shared.selectedModel
        
        let systemPrompt = """
        Ты — высокоточный синхронный переводчик реального времени для очков Ray-Ban Meta.
        Языковая пара: Русский <-> \(selectedForeignLanguage).
        
        Твоя задача:
        1. Определи язык входящей фразы.
        2. Если фраза на русском — переведи её на \(selectedForeignLanguage).
        3. Если фраза на иностранном (\(selectedForeignLanguage) или другом) — переведи её на русский язык.
        4. Ответь СТРОГО в формате JSON без markdown блоков:
        {
            "direction": "russian_to_foreign" или "foreign_to_russian",
            "translated_text": "текст перевода",
            "language_name": "название языка оригинала"
        }
        Переводи естественно, сохраняя живой разговорный стиль и интонацию.
        """
        
        do {
            let jsonString = try await GeminiService.shared.generateResponse(
                image: nil,
                prompt: trimmed,
                apiKey: apiKey,
                model: model,
                systemPrompt: systemPrompt
            )
            
            // Clean JSON
            let cleanJson = jsonString
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let data = cleanJson.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let translatedText = json["translated_text"] as? String,
                  let dirString = json["direction"] as? String else {
                // Fallback direct translation
                fallbackSpeak(original: trimmed, translated: jsonString)
                return
            }
            
            let direction: TranslationDirection = (dirString == "russian_to_foreign") ? .russianToForeign : .foreignToRussian
            let langName = json["language_name"] as? String ?? selectedForeignLanguage
            self.expectedDirection = direction == .russianToForeign ? .foreignToRussian : .russianToForeign
            
            self.currentTranslation = translatedText
            let turn = TranslationTurn(
                originalText: trimmed,
                translatedText: translatedText,
                direction: direction,
                language: langName
            )
            self.turns.append(turn)
            
            if direction == .foreignToRussian {
                // Foreigner spoke -> speak Russian translation privately into user's Ray-Ban Meta in-ear
                statusMessage = "Иностранец сказал (перевод в очки):"
                tts.speak(text: translatedText) { [weak self] in
                    self?.listenForNextTurn()
                }
            } else {
                // User spoke Russian -> speak foreign translation loudly for the foreigner
                statusMessage = "Вы сказали (перевод для собеседника):"
                speakForeign(text: translatedText, language: selectedForeignLanguage) { [weak self] in
                    self?.listenForNextTurn()
                }
            }
            
        } catch {
            statusMessage = "Ошибка перевода"
            listenForNextTurn()
        }
    }
    
    private func speakForeign(text: String, language: String, completion: @escaping () -> Void) {
        // Route the foreign-language phrase to the iPhone speaker so the other person can hear it.
        tts.configurePhoneSpeakerAudio()
        let code = voiceCodeForLanguage(language)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        if let voice = AVSpeechSynthesisVoice(language: code) {
            utterance.voice = voice
        }
        
        // Speak using foreign synthesizer. The delegate restores the glasses route after playback.
        foreignSpeechCompletion = completion
        foreignSynthesizer.speak(utterance)
    }
    
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.tts.configureAudioSession()
            let completion = self.foreignSpeechCompletion
            self.foreignSpeechCompletion = nil
            completion?()
        }
    }
    
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.tts.configureAudioSession()
            let completion = self.foreignSpeechCompletion
            self.foreignSpeechCompletion = nil
            completion?()
        }
    }
    
    private func fallbackSpeak(original: String, translated: String) {
        tts.speak(text: translated) { [weak self] in
            self?.listenForNextTurn()
        }
    }
    
    private func voiceCodeForLanguage(_ name: String) -> String {
        switch name.lowercased() {
        case "английский", "english": return "en-US"
        case "испанский", "spanish": return "es-ES"
        case "китайский", "chinese": return "zh-CN"
        case "немецкий", "german": return "de-DE"
        case "французский", "french": return "fr-FR"
        case "турецкий", "turkish": return "tr-TR"
        case "итальянский", "italian": return "it-IT"
        case "арабский", "arabic": return "ar-SA"
        case "японский", "japanese": return "ja-JP"
        case "корейский", "korean": return "ko-KR"
        default: return "en-US"
        }
    }
}
