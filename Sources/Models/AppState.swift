import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    // Services
    public let wearables = WearablesManager.shared
    public let speech = SpeechRecognitionService.shared
    public let tts = VoiceSynthesisService.shared
    public let customTTS = CustomTTSEngine.shared
    public let gemini = GeminiService.shared
    public let phoneCamera = CameraManager.shared
    public let proactive = ProactiveAgentManager.shared
    public let location = LocationTool.shared
    public let antiLost = AntiLostSentinelTool.shared
    
    // State
    @Published public var messages: [ChatMessage] = []
    @Published public var isAnalyzing: Bool = false
    @Published public var currentInputText: String = ""
    @Published public var statusMessage: String = "Готов к работе"
    @Published public var selectedVisionMode: VisionMode = .general
    
    // Non-secret settings stored in UserDefaults; API keys are stored in Keychain
    @Published public var apiKey: String = KeychainStore.shared.string(forKey: "gemini_api_key") ?? "" {
        didSet { KeychainStore.shared.set(apiKey, forKey: "gemini_api_key") }
    }
    @Published public var openAIApiKey: String = KeychainStore.shared.string(forKey: "openai_api_key") ?? "" {
        didSet { KeychainStore.shared.set(openAIApiKey, forKey: "openai_api_key") }
    }
    @AppStorage("openai_voice") public var openAIVoice: String = "onyx"
    @AppStorage("selected_model") public var selectedModel: String = "gemini-2.0-flash"
    @AppStorage("agent_name") public var agentName: String = "Джарвис"
    @AppStorage("agent_persona") public var selectedPersonaRaw: String = AgentPersona.jarvis.rawValue
    @AppStorage("system_prompt_custom") public var customSystemPrompt: String = ""
    @AppStorage("auto_listen_mode") public var autoListenMode: Bool = false
    @AppStorage("wake_word_enabled") public var wakeWordEnabled: Bool = true
    @AppStorage("use_glasses_camera") public var useGlassesCamera: Bool = true
    @AppStorage("greeting_on_connect") public var greetingOnConnect: Bool = true
    @AppStorage("speech_rate") public var speechRate: Double = 0.5
    @AppStorage("pitch_multiplier") public var pitchMultiplier: Double = 1.0
    
    public var selectedPersona: AgentPersona {
        get { AgentPersona(rawValue: selectedPersonaRaw) ?? .jarvis }
        set { selectedPersonaRaw = newValue.rawValue }
    }
    
    public var effectiveAgentName: String {
        let trimmed = agentName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Джарвис" : trimmed
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        migrateLegacySecretsToKeychain()
        
        // Sync TTS parameters
        tts.speechRate = Float(speechRate)
        tts.pitchMultiplier = Float(pitchMultiplier)
        proactive.greetingEnabled = greetingOnConnect
        
        // Listen to speech live updates
        speech.$liveTranscript
            .sink { [weak self] transcript in
                guard let self = self, self.speech.isListening else { return }
                self.currentInputText = transcript
            }
            .store(in: &cancellables)
            
        // Listen to glasses connection
        wearables.$isConnected
            .sink { [weak self] connected in
                guard let self = self else { return }
                if connected {
                    Task {
                        await self.proactive.onGlassesConnected()
                    }
                } else {
                    self.proactive.resetSession()
                }
            }
            .store(in: &cancellables)
    }
    
    private func migrateLegacySecretsToKeychain() {
        let defaults = UserDefaults.standard
        
        if KeychainStore.shared.string(forKey: "gemini_api_key") == nil,
           let legacyGeminiKey = defaults.string(forKey: "gemini_api_key"),
           !legacyGeminiKey.isEmpty {
            KeychainStore.shared.set(legacyGeminiKey, forKey: "gemini_api_key")
            apiKey = legacyGeminiKey
        }
        
        if KeychainStore.shared.string(forKey: "openai_api_key") == nil,
           let legacyOpenAIKey = defaults.string(forKey: "openai_api_key"),
           !legacyOpenAIKey.isEmpty {
            KeychainStore.shared.set(legacyOpenAIKey, forKey: "openai_api_key")
            openAIApiKey = legacyOpenAIKey
        }
        
        defaults.removeObject(forKey: "gemini_api_key")
        defaults.removeObject(forKey: "openai_api_key")
    }
    
    public var activeFrame: UIImage? {
        if useGlassesCamera && wearables.latestFrame != nil {
            return wearables.latestFrame
        }
        return phoneCamera.currentFrame
    }
    
    public var effectiveSystemPrompt: String {
        let personaPrompt = selectedPersona.promptDescription
        let modePrompt = selectedVisionMode.modeInstruction
        let memories = MemoryTool.shared.getAllMemories()
        
        var memorySection = ""
        if !memories.isEmpty {
            memorySection = "\nФакты из твоей памяти о пользователе:\n"
            for (k, v) in memories.prefix(10) {
                memorySection += "- \(k): \(v)\n"
            }
        }
        
        return """
        Ты — совершенный русскоязычный персональный AI-ассистент в очках Ray-Ban Meta.
        Твоё имя — «\(effectiveAgentName)». Откликайся на это имя и на обращения «Эй \(effectiveAgentName)».
        Пользователь носит очки и общается с тобой голосом. Твой ответ звучит прямо в его ухе.
        
        \(personaPrompt)
        
        \(modePrompt)
        
        \(memorySection)
        
        \(customSystemPrompt)
        
        ВАЖНЫЕ ПРАВИЛА:
        1. Отвечай кратко, емко, по делу на естественном русском языке (1-3 предложения).
        2. Если пользователь просит выполнить действие (поставить таймер, проверить расписание, переключить трек, отправить сообщение, найти телефон, посмотреть погоду, включить умный дом, очистить память) — используй соответствующие инструменты (Function Calling).
        3. Не используй списки из 10 пунктов и сложные форматирования, так как текст будет сразу озвучен голосом.
        """
    }
    
    public func toggleListening() {
        if speech.isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    public func startListening() {
        tts.stop()
        
        do {
            statusMessage = "Слушаю вас..."
            try speech.startListening(autoStopOnSilence: true, onPartialResult: { [weak self] partial in
                self?.currentInputText = partial
            }, onFinalResult: { [weak self] finalQuery in
                guard let self = self else { return }
                
                // Check for wake-word if enabled
                if self.wakeWordEnabled {
                    let wakeCheck = WakeWordEngine.shared.detectWakeWord(in: finalQuery, customName: self.effectiveAgentName)
                    if wakeCheck.detected {
                        self.currentInputText = wakeCheck.cleanQuery
                        Task {
                            await self.processQuery(queryText: wakeCheck.cleanQuery)
                        }
                        return
                    }
                }
                
                self.currentInputText = finalQuery
                Task {
                    await self.processQuery(queryText: finalQuery)
                }
            })
        } catch {
            statusMessage = "Ошибка микрофона: \(error.localizedDescription)"
        }
    }
    
    public func stopListening() {
        speech.stopListening()
        statusMessage = "Остановлено"
    }
    
    public func processQuery(queryText: String) async {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Run deterministic local commands before contacting Gemini. These continue to work without internet.
        let offlineResult = OfflineCommandEngine.shared.handleOfflineCommand(query: trimmed)
        if offlineResult.handled {
            let localMessage = ChatMessage(
                prompt: trimmed,
                response: offlineResult.response,
                image: nil,
                isLoading: false
            )
            messages.append(localMessage)
            statusMessage = "Готов"
            tts.speak(text: offlineResult.response)
            return
        }
        
        // Grab current frame snapshot
        let snapshot = activeFrame
        
        let message = ChatMessage(
            prompt: trimmed,
            response: "",
            image: snapshot,
            isLoading: true
        )
        
        messages.append(message)
        let messageId = message.id
        
        isAnalyzing = true
        statusMessage = "Агент думает..."
        
        do {
            let answer = try await gemini.generateResponse(
                image: snapshot,
                prompt: trimmed,
                apiKey: apiKey,
                model: selectedModel,
                systemPrompt: effectiveSystemPrompt
            )
            
            isAnalyzing = false
            statusMessage = "Отвечаю..."
            
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].response = answer
                messages[index].isLoading = false
            }
            
            // Speak response in Ray-Ban Meta glasses speakers (using OpenAI TTS if key set or Apple TTS)
            customTTS.speakAdvanced(
                text: answer,
                openAIApiKey: openAIApiKey,
                openAIVoice: openAIVoice
            ) { [weak self] in
                guard let self = self else { return }
                self.statusMessage = "Готов"
                
                // If auto continuous listen mode is enabled, resume listening
                if self.autoListenMode {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.startListening()
                    }
                }
            }
            
        } catch {
            isAnalyzing = false
            statusMessage = "Ошибка AI"
            
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].response = "Ошибка: \(error.localizedDescription)"
                messages[index].isLoading = false
            }
            
            tts.speak(text: "Не удалось выполнить запрос: \(error.localizedDescription)")
        }
    }
    
    public func askWithSnapshot() {
        let promptText: String
        switch selectedVisionMode {
        case .autoExpert: promptText = "Определи автомобиль перед мной: марку, модель, поколение и характеристики."
        case .fitnessCalories: promptText = "Оцени это блюдо: состав, калории и БЖУ."
        case .shopping: promptText = "Определи этот товар, бренд и примерную цену в интернет-магазинах."
        case .documents: promptText = "Прочитай и проанализируй текст документа или упаковки перед мной."
        case .sommelier: promptText = "Оцени винную этикетку или меню, посоветуй вкус и гастро-сочетания."
        case .diyRepair: promptText = "Проанализируй неисправность, код ошибки или деталь перед мной и предложи безопасные шаги диагностики."
        case .billSplit: promptText = "Считай чек в кадре и посчитай итог с чаевыми и сумму на каждого человека."
        case .photoDirector: promptText = "Оцени композицию и свет в кадре и дай совет для лучшего снимка."
        case .trivia: promptText = "Задай интересную загадку о месте или здании передо мной."
        case .chess: promptText = "Оцени позицию на шахматной доске и назови лучший следующий ход."
        case .driver: promptText = "Оцени дорожную обстановку перед мной, знаки и важные детали."
        case .prompter: promptText = "Подскажи умный ответ и аргументы для текущего разговора."
        case .translator: promptText = "Переведи весь иностранный текст в кадре на русский язык."
        case .tourGuide: promptText = "Расскажи интересный исторический факт об этом месте или здании."
        case .general: promptText = "Что перед мной? Опиши самое главное."
        }
        
        Task {
            await processQuery(queryText: promptText)
        }
    }
    
    public func clearHistory() {
        messages.removeAll()
    }
}
