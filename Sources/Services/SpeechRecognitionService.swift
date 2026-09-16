import AVFoundation
import Speech
import Combine

public final class SpeechRecognitionService: ObservableObject {
    public static let shared = SpeechRecognitionService()
    
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published public var isListening: Bool = false
    @Published public var liveTranscript: String = ""
    @Published public var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    private var silenceTimer: Timer?
    private var silenceThreshold: TimeInterval = 1.6
    private var onFinalResultCallback: ((String) -> Void)?
    
    private init() {
        requestAuthorization()
    }
    
    public func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
            }
        }
    }
    
    public func startListening(
        localeIdentifier: String = "ru-RU",
        autoStopOnSilence: Bool = false,
        onPartialResult: ((String) -> Void)? = nil,
        onFinalResult: @escaping (String) -> Void
    ) throws {
        stopListening()
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw NSError(domain: "SpeechService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Распознавание русской речи недоступно на данном устройстве."])
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        self.onFinalResultCallback = onFinalResult
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        DispatchQueue.main.async {
            self.isListening = true
            self.liveTranscript = ""
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcript = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.liveTranscript = transcript
                    onPartialResult?(transcript)
                }
                
                if autoStopOnSilence {
                    self.resetSilenceTimer()
                }
            }
            
            if error != nil || result?.isFinal == true {
                self.handleStopAndFinalize()
            }
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            self?.handleStopAndFinalize()
        }
    }
    
    private func handleStopAndFinalize() {
        guard isListening else { return }
        let final = liveTranscript
        stopListening()
        if !final.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onFinalResultCallback?(final)
        }
    }
    
    public func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
}
