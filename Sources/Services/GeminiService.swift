import UIKit

public enum GeminiError: LocalizedError {
    case invalidURL
    case missingAPIKey
    case networkError(String)
    case apiError(String)
    case invalidResponse
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL для запроса к Gemini API"
        case .missingAPIKey:
            return "Не указан API ключ Gemini. Укажите его в настройках."
        case .networkError(let message):
            return "Ошибка сети: \(message)"
        case .apiError(let message):
            return "Ошибка Gemini API: \(message)"
        case .invalidResponse:
            return "Получен некорректный ответ от сервера."
        }
    }
}

public final class GeminiService: @unchecked Sendable {
    public static let shared = GeminiService()
    
    private init() {}
    
    public func generateResponse(
        image: UIImage?,
        prompt: String,
        apiKey: String,
        model: String = "gemini-3.6-flash",
        systemPrompt: String = "Ты — русскоязычный персональный AI-ассистент в очках Ray-Ban Meta. Отвечай кратко, емко и по делу (1-3 предложения), так как ответ будет озвучен голосом."
    ) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }
        
        let retiredModels = ["gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-pro"]
        let effectiveModel = retiredModels.contains(model) ? "gemini-3.6-flash" : model
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(effectiveModel):generateContent"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }
        
        var userParts: [[String: Any]] = []
        
        // Add image if available
        if let image = image {
            let processedImage = resizeImageIfNeeded(image, maxDimension: 1024)
            if let jpegData = processedImage.jpegData(compressionQuality: 0.7) {
                let base64Image = jpegData.base64EncodedString()
                userParts.append([
                    "inline_data": [
                        "mime_type": "image/jpeg",
                        "data": base64Image
                    ]
                ])
            }
        }
        
        // Add user prompt
        let finalPromptText = prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            ? "Опиши кратко, что ты видишь прямо сейчас перед пользователем." 
            : prompt
        
        userParts.append([
            "text": finalPromptText
        ])
        
        let toolDeclarations = AgentToolManager.shared.toolDeclarations
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": userParts
                ]
            ],
            "tools": [
                [
                    "functionDeclarations": toolDeclarations
                ]
            ],
            "system_instruction": [
                "parts": [
                    [
                        "text": systemPrompt
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 300
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(trimmedKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 25
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                throw GeminiError.apiError(message)
            }
            throw GeminiError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let responseParts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.invalidResponse
        }
        
        // Check for Function Call
        for part in responseParts {
            let functionCall = (part["functionCall"] as? [String: Any])
                ?? (part["function_call"] as? [String: Any])
            if let functionCall,
               let functionName = functionCall["name"] as? String {
                let args = functionCall["args"] as? [String: Any]
                    ?? functionCall["arguments"] as? [String: Any]
                    ?? [:]
                
                // Execute Native Tool on MainActor
                let toolResult = await AgentToolManager.shared.executeTool(name: functionName, arguments: args)
                
                // If it's a direct action confirmation, return it directly
                if !toolResult.isEmpty {
                    return toolResult
                }
            }
            
            if let text = part["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return "Действие выполнено."
    }
    
    private func resizeImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
}
