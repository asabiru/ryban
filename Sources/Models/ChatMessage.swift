import SwiftUI

public struct ChatMessage: Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public var prompt: String
    public var response: String
    public var image: UIImage?
    public var isLoading: Bool
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        prompt: String,
        response: String = "",
        image: UIImage? = nil,
        isLoading: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.prompt = prompt
        self.response = response
        self.image = image
        self.isLoading = isLoading
    }
    
    public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.prompt == rhs.prompt &&
        lhs.response == rhs.response &&
        lhs.isLoading == rhs.isLoading
    }
}
