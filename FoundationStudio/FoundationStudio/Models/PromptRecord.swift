import Foundation
import SwiftData

/// Records the full prompt, system instructions, and generation metrics
/// for each user interaction. Useful for reviewing and reusing past prompts.
@Model
final class PromptRecord {
    var id: UUID

    /// The full user prompt text.
    var promptText: String

    /// System instructions active at the time of this prompt.
    var systemInstructions: String?

    /// The model's complete response text.
    var responseText: String?

    var timestamp: Date

    /// Token count of the generated response.
    var responseTokenCount: Int?

    /// Average tokens-per-second achieved during generation.
    var tokensPerSecond: Double?

    /// Total generation duration in seconds.
    var generationDurationSeconds: Double?

    /// Temperature parameter used (reserved for future use).
    var temperature: Double?

    /// Maximum token limit set (reserved for future use).
    var maxTokens: Int?

    var thread: ChatThread?

    init(
        promptText: String,
        systemInstructions: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.id = UUID()
        self.promptText = promptText
        self.systemInstructions = systemInstructions
        self.timestamp = Date()
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}
