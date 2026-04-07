import Foundation
import SwiftData

/// Role of a message in a conversation.
enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

/// Represents a single message within a chat thread.
/// Assistant messages include generation metrics (token count, TPS, duration).
@Model
final class Message {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date

    /// Estimated token count for the generated response (assistant messages only).
    var tokenCount: Int?

    /// Final average tokens-per-second measured during generation (assistant messages only).
    var finalTokensPerSecond: Double?

    /// Total generation duration in seconds (assistant messages only).
    var generationDurationSeconds: Double?

    var thread: ChatThread?

    init(
        role: MessageRole,
        content: String,
        tokenCount: Int? = nil,
        finalTokensPerSecond: Double? = nil,
        generationDurationSeconds: Double? = nil
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.tokenCount = tokenCount
        self.finalTokensPerSecond = finalTokensPerSecond
        self.generationDurationSeconds = generationDurationSeconds
    }
}
