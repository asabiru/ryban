import SwiftUI

public struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var storage = GlassesStorageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showApiKey: Bool = false
    @State private var showOpenAIKey: Bool = false
    @State private var cleanupNotice: String?
    
    public var body: some View {
        NavigationView {
            Form {
                // Section: Persona & Character
                Section(header: Text("Личность и Характер AI")) {
                    Picker("Характер ассистента", selection: $appState.selectedPersonaRaw) {
                        ForEach(AgentPersona.allCases) { persona in
                            Text(persona.title).tag(persona.rawValue)
                        }
                    }
                    
                    TextField("Имя агента", text: $appState.agentName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                    Text("Агент будет откликаться на «Эй \(appState.effectiveAgentName)», «\(appState.effectiveAgentName)» и «Слушай \(appState.effectiveAgentName)».")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Toggle("Приветствие при надевании очков", isOn: $appState.greetingOnConnect)
                        .onChange(of: appState.greetingOnConnect) { val in
                            appState.proactive.greetingEnabled = val
                        }
                    
                    Toggle("Голосовая активация (Wake-Word)", isOn: $appState.wakeWordEnabled)
                    if appState.wakeWordEnabled {
                        Text("Фразы активации: «Эй \(appState.effectiveAgentName)», «\(appState.effectiveAgentName)», «Очки»")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Section: Ultra-Realistic Voices (OpenAI / Apple)
                Section(header: Text("Голосовой движок и Реалистичные голоса"), footer: Text("Опционально: введите ключ OpenAI для гиперреалистичного голоса с эмоциями.")) {
                    HStack {
                        if showOpenAIKey {
                            TextField("OpenAI API Key (Опционально)", text: $appState.openAIApiKey)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("OpenAI API Key (Опционально)", text: $appState.openAIApiKey)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        Button(action: { showOpenAIKey.toggle() }) {
                            Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !appState.openAIApiKey.isEmpty {
                        Picker("Голос OpenAI", selection: $appState.openAIVoice) {
                            Text("Onyx (Глубокий мужской)").tag("onyx")
                            Text("Nova (Приятный женский)").tag("nova")
                            Text("Alloy (Нейтральный)").tag("alloy")
                            Text("Echo (Четкий мужской)").tag("echo")
                            Text("Fable (Британский стиль)").tag("fable")
                            Text("Shimmer (Мягкий женский)").tag("shimmer")
                        }
                    }
                    
                    Toggle("Авто-режим (Непрерывный диалог)", isOn: $appState.autoListenMode)
                    
                    Button(action: {
                        appState.customTTS.speakAdvanced(
                            text: "Привет! Проверка звука в очках Ray-Ban Meta.",
                            openAIApiKey: appState.openAIApiKey,
                            openAIVoice: appState.openAIVoice
                        )
                    }) {
                        HStack {
                            Image(systemName: "speaker.wave.3.fill")
                            Text("Прослушать голос в очках")
                        }
                    }
                }
                
                // Section: Google Gemini API
                Section(header: Text("Google Gemini AI"), footer: Text("Бесплатный API ключ можно получить на сайте aistudio.google.com")) {
                    HStack {
                        if showApiKey {
                            TextField("AI Studio API Key", text: $appState.apiKey)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("AI Studio API Key", text: $appState.apiKey)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        Button(action: { showApiKey.toggle() }) {
                            Image(systemName: showApiKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Picker("Модель", selection: $appState.selectedModel) {
                        Text("Gemini 3.6 Flash (Рекомендуется)").tag("gemini-3.6-flash")
                    }
                }
                
                // Section: Memory & Storage Optimization
                Section(header: Text("Очистка памяти и кэша очков")) {
                    if let report = storage.currentReport {
                        HStack {
                            Text("Кэш и буферы:")
                            Spacer()
                            Text("\(String(format: "%.1f", report.cacheSizeMB + report.tempSizeMB)) МБ")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Оперативная память:")
                            Spacer()
                            Text("\(Int(report.appMemoryMB)) МБ")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Статус:")
                            Spacer()
                            Text(report.statusDescription)
                                .foregroundColor(report.statusDescription.contains("норме") ? .green : .orange)
                        }
                    }
                    
                    Button(action: {
                        let res = storage.clearMemoryAndCache()
                        cleanupNotice = res.message
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .foregroundColor(.blue)
                            Text("Очистить память и кэш очков")
                        }
                    }
                    
                    if let notice = cleanupNotice {
                        Text(notice)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                // Section: Ray-Ban Meta Connection
                Section(header: Text("Очки Ray-Ban Meta")) {
                    HStack {
                        Text("Статус SDK:")
                        Spacer()
                        Text(appState.wearables.statusMessage)
                            .foregroundColor(appState.wearables.isConnected ? .green : .secondary)
                            .font(.subheadline)
                    }
                    
                    Toggle("Использовать камеру очков", isOn: $appState.useGlassesCamera)
                    
                    Button(action: {
                        appState.wearables.startRegistration()
                    }) {
                        HStack {
                            Image(systemName: "link.badge.plus")
                            Text("Подключить к Meta View")
                        }
                    }
                    
                    if let error = appState.wearables.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Section: Data
                Section {
                    Button(role: .destructive, action: {
                        appState.clearHistory()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Очистить историю диалогов")
                        }
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarItems(trailing: Button("Готово") {
                dismiss()
            })
            .onAppear {
                storage.updateReport()
            }
        }
    }
}
