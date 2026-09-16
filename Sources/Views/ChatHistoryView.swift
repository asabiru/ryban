import SwiftUI

public struct ChatHistoryView: View {
    let messages: [ChatMessage]
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if messages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("Задайте вопрос голосом")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Нажмите кнопку микрофона и спросите, например:\n«Что это за здание?» или «Переведи эту вывеску»")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(messages) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct MessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // User Query
            HStack(alignment: .top, spacing: 10) {
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.prompt)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            
            // AI Response
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                    .padding(.top, 2)
                
                if message.isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Анализирую...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(message.response)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(Color.blue.opacity(0.12))
            .cornerRadius(12)
        }
    }
}
