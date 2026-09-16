import SwiftUI

public struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @ObservedObject private var interpreter = LiveInterpreterService.shared
    @ObservedObject private var meeting = MeetingTranscriberTool.shared
    
    @State private var showSettings = false
    @State private var showInterpreter = false
    @State private var showDashboard = false
    @State private var showPersonaSheet = false
    @State private var isPulsing = false
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Status Bar
                HStack(spacing: 6) {
                    // Glasses Status Badge
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task {
                            await appState.wearables.startRegistration()
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "eyeglasses")
                                .foregroundColor(appState.wearables.isConnected ? .green : .secondary)
                            Text(appState.wearables.isConnected ? "Очки в сети" : "Очки выкл")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Persona Selector Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showPersonaSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "theatermasks.fill")
                                .foregroundColor(.purple)
                                .font(.caption)
                            Text(appState.effectiveAgentName)
                                .font(.caption.bold())
                                .lineLimit(1)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.12))
                        .cornerRadius(12)
                    }
                    
                    // Live Interpreter Quick Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showInterpreter = true
                    }) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(interpreter.isActive ? Color.green : Color.blue)
                                .frame(width: 7, height: 7)
                            Text(interpreter.isActive ? "Перевод: ВКЛ" : "Перевод")
                                .font(.caption.bold())
                        }
                        .foregroundColor(interpreter.isActive ? .green : .blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(interpreter.isActive ? Color.green.opacity(0.15) : Color.blue.opacity(0.12))
                        .cornerRadius(12)
                    }
                    
                    // Superpower Tools Dashboard Button
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showDashboard = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.orange)
                            Text("Инструменты")
                                .font(.caption.bold())
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)
                
                // Vision Mode Switcher Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(VisionMode.allCases) { mode in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                appState.selectedVisionMode = mode
                            }) {
                                Text(mode.title)
                                    .font(.caption.weight(appState.selectedVisionMode == mode ? .bold : .regular))
                                    .foregroundColor(appState.selectedVisionMode == mode ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(appState.selectedVisionMode == mode ? Color.blue : Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 4)
                
                // Active Meeting Recording Live Banner
                if meeting.isRecording {
                    HStack {
                        Image(systemName: "record.circle.fill")
                            .foregroundColor(.red)
                        Text("Идет запись встречи...")
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                _ = await meeting.finishMeetingAndSummarize()
                            }
                        }) {
                            Text("Завершить и Итоги")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
                
                // Camera View
                CameraPreviewView(
                    image: appState.activeFrame,
                    isGlassesCamera: appState.useGlassesCamera && appState.wearables.latestFrame != nil,
                    isStreaming: appState.wearables.isStreaming || appState.phoneCamera.isRunning
                )
                .frame(height: 190)
                .padding(.horizontal)
                .padding(.vertical, 4)
                
                // Live speech transcript banner
                if !appState.currentInputText.isEmpty || appState.speech.isListening {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .foregroundColor(.blue)
                        Text(appState.currentInputText.isEmpty ? "Слушаю..." : appState.currentInputText)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
                
                // Chat / Actions History
                ChatHistoryView(messages: appState.messages)
                
                // Bottom Controls & Action Bar
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        // Quick Action: Snapshot + Vision Mode
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            appState.askWithSnapshot()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "sparkle.magnifyingglass")
                                    .font(.system(size: 18))
                                Text("Что вижу?")
                                    .font(.caption2.bold())
                            }
                            .foregroundColor(.primary)
                            .frame(width: 72, height: 62)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                        }
                        
                        // Main Push-to-Talk / Listening Button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            appState.toggleListening()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(appState.speech.isListening ? Color.red : Color.blue)
                                    .frame(width: 74, height: 74)
                                    .scaleEffect(appState.speech.isListening && isPulsing ? 1.12 : 1.0)
                                    .animation(
                                        appState.speech.isListening 
                                            ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                            : .default,
                                        value: isPulsing
                                    )
                                
                                Image(systemName: appState.speech.isListening ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .onChange(of: appState.speech.isListening) { listening in
                            isPulsing = listening
                        }
                        
                        // Stop Speech / Mute button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            appState.tts.stop()
                            appState.stopListening()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "speaker.slash")
                                    .font(.system(size: 18))
                                Text("Стоп")
                                    .font(.caption2.bold())
                            }
                            .foregroundColor(.primary)
                            .frame(width: 72, height: 62)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                        }
                    }
                    
                    Text(appState.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemBackground))
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPersonaSheet) {
                PersonaSelectorSheet(appState: appState)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(appState: appState)
            }
            .sheet(isPresented: $showInterpreter) {
                InterpreterView()
            }
            .sheet(isPresented: $showDashboard) {
                SuperpowerDashboardView()
            }
            .onAppear {
                if !appState.useGlassesCamera {
                    appState.phoneCamera.startSession()
                }
            }
        }
    }
}
