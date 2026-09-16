import Foundation
import UIKit
import AVFoundation
import Combine
import ShazamKit

// MARK: - Meeting & Lecture Transcriber & Summarizer
@MainActor
public final class MeetingTranscriberTool: ObservableObject {
    public static let shared = MeetingTranscriberTool()
    
    @Published public var isRecording: Bool = false
    @Published public var recordedPhrases: [String] = []
    @Published public var meetingSummary: String = ""
    
    private init() {}
    
    public func startMeetingRecording() -> String {
        isRecording = true
        recordedPhrases.removeAll()
        meetingSummary = ""
        
        SpeechRecognitionService.shared.stopListening()
        
        // Start continuous background speech capture for meeting
        try? SpeechRecognitionService.shared.startListening(autoStopOnSilence: false, onPartialResult: nil, onFinalResult: { [weak self] phrase in
            guard let self = self, self.isRecording else { return }
            let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                self.recordedPhrases.append(trimmed)
            }
        })
        
        return "Запись встречи начата. Нажмите 'Завершить' или скажите 'Заверши запись встречи', когда закончите."
    }
    
    public func finishMeetingAndSummarize() async -> String {
        guard isRecording else {
            return "Запись встречи не была активна."
        }
        
        isRecording = false
        SpeechRecognitionService.shared.stopListening()
        
        let fullTranscript = recordedPhrases.joined(separator: " ")
        if fullTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Запись встречи завершена. Речь не была зафиксирована."
        }
        
        let prompt = """
        Сделай четкую и структурированную выжимку этой встречи на русском языке:
        1. Главная тема и тезисы
        2. Принятые решения
        3. Список задач (Action Items)
        
        Транскрипт встречи:
        \(fullTranscript)
        """
        
        do {
            let summary = try await GeminiService.shared.generateResponse(
                image: nil,
                prompt: prompt,
                apiKey: AppState.shared.apiKey,
                model: AppState.shared.selectedModel,
                systemPrompt: "Ты — бизнес-аналитик и секретарь. Составляй компактные и полезные выжимки деловых встреч."
            )
            
            self.meetingSummary = summary
            
            // Save to Voice Notes automatically
            _ = VoiceNotesTool.shared.saveNote(
                title: "Итоги встречи (\(Date().formatted(date: .abbreviated, time: .shortened)))",
                content: summary,
                category: "Встречи"
            )
            
            return "Встреча обработана и сохранена в Заметки. Краткий итог: \(summary)"
        } catch {
            return "Встреча завершена, но не удалось сгенерировать саммари: \(error.localizedDescription)"
        }
    }
}

// MARK: - Whisper / Stealth Mode Tool
public final class WhisperModeTool {
    public static let shared = WhisperModeTool()
    private init() {}
    
    public func setWhisperMode(enabled: Bool) -> String {
        if enabled {
            AppState.shared.speechRate = 0.45
            AppState.shared.pitchMultiplier = 0.85
            VoiceSynthesisService.shared.speechRate = 0.45
            VoiceSynthesisService.shared.pitchMultiplier = 0.85
            return "Режим шепота включен. Говорю тихо и максимально кратко прямо вам в ухо."
        } else {
            AppState.shared.speechRate = 0.5
            AppState.shared.pitchMultiplier = 1.0
            VoiceSynthesisService.shared.speechRate = 0.5
            VoiceSynthesisService.shared.pitchMultiplier = 1.0
            return "Обычный режим голоса восстановлен."
        }
    }
}

// MARK: - Music Shazam Identifier Tool
@MainActor
public final class MusicIdentifierTool: NSObject, SHSessionDelegate {
    public static let shared = MusicIdentifierTool()
    
    private let audioEngine = AVAudioEngine()
    private let shazamSession = SHSession()
    private var resultContinuation: CheckedContinuation<String, Never>?
    private var timeoutTask: Task<Void, Never>?
    
    private override init() {
        super.init()
        shazamSession.delegate = self
    }
    
    public func identifyMusic(contextHint: String? = nil) async -> String {
        #if FREE_BUILD
        return "ShazamKit недоступен в бесплатной подписи Apple."
        #else
        _ = contextHint
        stopCapture()
        
        return await withCheckedContinuation { continuation in
            self.resultContinuation = continuation
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                let inputNode = audioEngine.inputNode
                inputNode.removeTap(onBus: 0)
                let format = inputNode.outputFormat(forBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, audioTime in
                    self?.shazamSession.matchStreamingBuffer(buffer, at: audioTime)
                }
                
                audioEngine.prepare()
                try audioEngine.start()
                timeoutTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    guard !Task.isCancelled else { return }
                    self?.finish(result: "Не удалось определить композицию за 12 секунд.")
                }
            } catch {
                finish(result: "Не удалось включить микрофон для распознавания музыки: \(error.localizedDescription)")
            }
        }
        #endif
    }
    
    public nonisolated func session(_ session: SHSession, didFind match: SHMatch) {
        let item = match.mediaItems.first
        let title = item?.title ?? "Неизвестный трек"
        let artist = item?.artist.map { " — \($0)" } ?? ""
        Task { @MainActor [weak self] in
            self?.finish(result: "Найден трек: \(title)\(artist).")
        }
    }
    
    public nonisolated func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature) {
        Task { @MainActor [weak self] in
            self?.finish(result: "Композиция не найдена в каталоге Shazam.")
        }
    }
    
    private func finish(result: String) {
        stopCapture()
        let continuation = resultContinuation
        resultContinuation = nil
        continuation?.resume(returning: result)
    }
    
    private func stopCapture() {
        timeoutTask?.cancel()
        timeoutTask = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
