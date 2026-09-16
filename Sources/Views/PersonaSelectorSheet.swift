import SwiftUI

public struct PersonaSelectorSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Выберите стиль и характер общения вашего ассистента в очках Ray-Ban")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 4)
                    
                    ForEach(AgentPersona.allCases) { persona in
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            appState.selectedPersona = persona
                            
                            // Play greeting sample in selected persona tone
                            let sample: String
                            switch persona {
                            case .kentBro: sample = "Здорово, бро! Теперь я на связи в режиме кента. Зажигаем!"
                            case .official: sample = "Добрый день. Официальный режим активирован. Чем могу быть полезен?"
                            case .jarvis: sample = "Тактический протокол Джарвис запущен. Все системы функционируют штатно."
                            case .sarcastic: sample = "О, режим сарказма. Наконец-то поговорим как умные люди."
                            case .mentor: sample = "Режим ментора включен. Сделай вдох, я помогу найти гармонию в каждом моменте."
                            case .professor: sample = "Академический режим активен. Готов исследовать окружающий мир во всех деталях."
                            }
                            appState.tts.speak(text: sample)
                        }) {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(persona.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if appState.selectedPersona == persona {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.title3)
                                        }
                                    }
                                    
                                    Text(persona.promptDescription.replacingOccurrences(of: "ТВОЙ ХАРАКТЕР: ", with: ""))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .padding(14)
                            .background(appState.selectedPersona == persona ? Color.blue.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(appState.selectedPersona == persona ? Color.blue : Color.clear, lineWidth: 2)
                            )
                            .cornerRadius(14)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("🎭 Характер Агента")
            .navigationBarItems(trailing: Button("Готово") {
                dismiss()
            })
        }
    }
}
