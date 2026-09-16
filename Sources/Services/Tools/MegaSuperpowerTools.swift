import Foundation
import UIKit
import AVFoundation
import AudioToolbox
import Combine

// MARK: - 1. Find My Phone Tool
public final class FindMyPhoneTool: @unchecked Sendable {
    public static let shared = FindMyPhoneTool()
    private var isAlarmPlaying = false
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    @MainActor
    public func triggerFindPhoneAlarm() -> String {
        // 1. Play loud alert sound
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        
        // 2. Flash Torch
        flashTorch(times: 8)
        
        // Repeat sound after 1s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            AudioServicesPlaySystemSound(1005)
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        
        return "Издаю громкий сигнал на телефоне и мигаю вспышкой! Я здесь!"
    }
    
    private func flashTorch(times: Int) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        
        for i in 0..<times {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                try? device.lockForConfiguration()
                if i % 2 == 0 {
                    try? device.setTorchModeOn(level: 1.0)
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            }
        }
    }
}

// MARK: - 2. Workout & Rest Coach Tool
@MainActor
public final class WorkoutCoachTool: ObservableObject, @unchecked Sendable {
    public static let shared = WorkoutCoachTool()
    
    @Published public var isResting: Bool = false
    @Published public var remainingRestSeconds: Int = 0
    private var timer: Timer?
    
    private init() {}
    
    public func startRestTimer(seconds: Int = 60) -> String {
        stopRestTimer()
        
        self.isResting = true
        self.remainingRestSeconds = seconds
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingRestSeconds -= 1
            
            if self.remainingRestSeconds == 30 {
                VoiceSynthesisService.shared.speak(text: "Осталось 30 секунд отдыха.")
            } else if self.remainingRestSeconds == 10 {
                VoiceSynthesisService.shared.speak(text: "10 секунд. Приготовься.")
            } else if self.remainingRestSeconds <= 0 {
                self.stopRestTimer()
                VoiceSynthesisService.shared.speak(text: "Время отдыха вышло! Начинай следующий подход!")
            }
        }
        
        return "Таймер отдыха на \(seconds) секунд запущен. Я подскажу, когда начинать следующий подход."
    }
    
    public func stopRestTimer() {
        timer?.invalidate()
        timer = nil
        isResting = false
        remainingRestSeconds = 0
    }
}

// MARK: - 3. Driver & Co-Pilot Tool
public final class DriverCopilotTool: @unchecked Sendable {
    public static let shared = DriverCopilotTool()
    private init() {}
    
    @MainActor
    public func findGasStation() -> String {
        return LocationTool.shared.openMaps(query: "ближайшая заправка")
    }
    
    @MainActor
    public func findCarWash() -> String {
        return LocationTool.shared.openMaps(query: "автомойка")
    }
}

// MARK: - 4. Wake-Word Detection Engine
public final class WakeWordEngine: @unchecked Sendable {
    public static let shared = WakeWordEngine()
    
    public let defaultWakeWords = [
        "эй джарвис", "джарвис",
        "слушай бро", "бро",
        "очки", "эй очки",
        "слушай агент", "ассистент",
        "помоги мне"
    ]
    
    private init() {}
    
    public func detectWakeWord(in phrase: String, customName: String? = nil) -> (detected: Bool, cleanQuery: String) {
        let lower = phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = (customName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var wakeWords = defaultWakeWords
        
        if !normalizedName.isEmpty {
            wakeWords.append(normalizedName)
            wakeWords.append("эй \(normalizedName)")
            wakeWords.append("слушай \(normalizedName)")
        }
        
        // Match the longest phrase first so «Эй Макс» wins over «Макс».
        for wake in wakeWords.sorted(by: { $0.count > $1.count }) {
            let hasBoundary = [" ", ",", ".", "!", "?", ":"].contains { lower.hasPrefix(wake + $0) }
            if lower == wake || hasBoundary {
                var query = String(lower.dropFirst(wake.count))
                query = query.trimmingCharacters(in: CharacterSet(charactersIn: ",.!? \t\n"))
                return (true, query.isEmpty ? "Привет, я слушаю тебя" : query)
            }
        }
        
        return (false, phrase)
    }
}

// MARK: - 5. Custom AI TTS Engine (OpenAI / ElevenLabs / Apple)
public final class CustomTTSEngine: @unchecked Sendable {
    public static let shared = CustomTTSEngine()
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    public func speakAdvanced(
        text: String,
        openAIApiKey: String? = nil,
        openAIVoice: String = "onyx",
        completion: (() -> Void)? = nil
    ) {
        let trimmedKey = (openAIApiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If OpenAI API key provided, use ultra-realistic OpenAI TTS
        if !trimmedKey.isEmpty {
            Task {
                do {
                    let audioData = try await fetchOpenAITTSAudio(text: text, apiKey: trimmedKey, voice: openAIVoice)
                    await playAudioData(audioData, completion: completion)
                } catch {
                    // Fallback to Apple TTS
                    await MainActor.run {
                        VoiceSynthesisService.shared.speak(text: text, completion: completion)
                    }
                }
            }
        } else {
            // Default native Apple Voice Synthesis
            VoiceSynthesisService.shared.speak(text: text, completion: completion)
        }
    }
    
    private func fetchOpenAITTSAudio(text: String, apiKey: String, voice: String) async throws -> Data {
        let url = URL(string: "https://api.openai.com/v1/audio/speech")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": voice,
            "response_format": "mp3"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "OpenAITTS", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI TTS Error"])
        }
        return data
    }
    
    @MainActor
    private func playAudioData(_ data: Data, completion: (() -> Void)?) {
        do {
            VoiceSynthesisService.shared.configureAudioSession()
            self.audioPlayer = try AVAudioPlayer(data: data)
            self.audioPlayer?.prepareToPlay()
            self.audioPlayer?.play()
            
            let duration = self.audioPlayer?.duration ?? 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                completion?()
            }
        } catch {
            VoiceSynthesisService.shared.speak(text: "", completion: completion)
        }
    }
}
