import AVFoundation
import Combine

public final class VoiceSynthesisService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = VoiceSynthesisService()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published public var isSpeaking: Bool = false
    public var onSpeechFinished: (() -> Void)?
    public var onSpeechStarted: (() -> Void)?
    
    public var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    public var pitchMultiplier: Float = 1.0
    
    override private init() {
        super.init()
        synthesizer.delegate = self
    }
    
    public func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Prefer the glasses' hands-free Bluetooth route when iOS exposes it.
            if let bluetoothInput = audioSession.availableInputs?.first(where: { $0.portType == .bluetoothHFP }) {
                try? audioSession.setPreferredInput(bluetoothInput)
            }
        } catch {
            print("Failed to configure audio session for TTS: \(error)")
        }
    }
    
    public func configurePhoneSpeakerAudio() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to route audio to the iPhone speaker: \(error)")
        }
    }
    
    public func speak(text: String, completion: (() -> Void)? = nil) {
        stop()
        self.onSpeechFinished = completion
        
        configureAudioSession()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.pitchMultiplier = pitchMultiplier
        
        // Find best Russian voice
        if let russianVoice = AVSpeechSynthesisVoice(language: "ru-RU") {
            utterance.voice = russianVoice
        }
        
        synthesizer.speak(utterance)
    }
    
    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
            self.onSpeechStarted?()
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.onSpeechFinished?()
        }
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
