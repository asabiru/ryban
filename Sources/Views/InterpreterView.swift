import SwiftUI

public struct InterpreterView: View {
    @ObservedObject var interpreter = LiveInterpreterService.shared
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Top Language Switcher Bar
                HStack {
                    Text("Язык собеседника:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Picker("Язык", selection: $interpreter.selectedForeignLanguage) {
                        ForEach(interpreter.availableLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(interpreter.isActive)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Live Status Banner
                HStack(spacing: 8) {
                    Circle()
                        .fill(interpreter.isActive ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    
                    Text(interpreter.statusMessage)
                        .font(.subheadline.bold())
                        .foregroundColor(interpreter.isActive ? .primary : .secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Transcript & Live Turns
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if interpreter.turns.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "globe.americas.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.blue.opacity(0.8))
                                        .padding(.top, 40)
                                    
                                    Text("Синхронный диалог")
                                        .font(.headline)
                                    
                                    Text("1. Наденьте очки и включите режим.\n2. Вы говорите на русском ➔ перевод звучит для собеседника.\n3. Собеседник говорит на иностранном ➔ перевод звучит вам в очки.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            } else {
                                ForEach(interpreter.turns) { turn in
                                    TranslationCard(turn: turn)
                                        .id(turn.id)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onChange(of: interpreter.turns.count) { _ in
                        if let last = interpreter.turns.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Bottom Big Action Button
                VStack(spacing: 8) {
                    Button(action: {
                        interpreter.toggleInterpreter()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: interpreter.isActive ? "stop.circle.fill" : "waveform.badge.mic")
                                .font(.system(size: 24))
                            
                            Text(interpreter.isActive ? "Остановить перевод" : "Начать синхронный перевод")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(interpreter.isActive ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 12)
            }
            .navigationTitle("🌐 Живой переводчик")
            .navigationBarItems(trailing: Button("Закрыть") {
                dismiss()
            })
        }
    }
}

private struct TranslationCard: View {
    let turn: TranslationTurn
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: turn.direction == .russianToForeign ? "person.fill" : "person.2.fill")
                    Text(turn.direction == .russianToForeign ? "Вы (Русский)" : "Собеседник (\(turn.language))")
                        .font(.caption.bold())
                }
                .foregroundColor(turn.direction == .russianToForeign ? .blue : .green)
                
                Spacer()
                
                Text(turn.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(turn.originalText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: turn.direction == .russianToForeign ? "speaker.wave.2.fill" : "headphones")
                    .foregroundColor(.primary)
                    .font(.caption)
                    .padding(.top, 2)
                
                Text(turn.translatedText)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(14)
        .background(turn.direction == .russianToForeign ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
        .cornerRadius(14)
    }
}
