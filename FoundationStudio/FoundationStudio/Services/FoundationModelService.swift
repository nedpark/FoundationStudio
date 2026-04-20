import Foundation
import FoundationModels
import Observation

/// Result of a completed model generation.
struct GenerationResult: Sendable {
    let text: String
    let tokenCount: Int
    let tokensPerSecond: Double
    let durationSeconds: Double
}

/// Errors specific to the Foundation Model service.
enum FoundationModelServiceError: LocalizedError {
    case sessionNotAvailable
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .sessionNotAvailable:
            "Could not create a language model session."
        case .modelUnavailable(let reason):
            "Model unavailable: \(reason)"
        }
    }
}

/// Manages interaction with Apple's on-device Foundation Models.
/// Provides streaming text generation with real-time tokens-per-second tracking.
@Observable
@MainActor
final class FoundationModelService {

    // MARK: - Observable State

    /// Whether the model is currently generating a response.
    private(set) var isGenerating = false

    /// The accumulated text being streamed from the model.
    private(set) var streamingText = ""

    /// Current tokens-per-second calculated during active streaming.
    private(set) var currentTPS: Double = 0

    /// Estimated token count during the current generation.
    private(set) var estimatedTokenCount: Int = 0

    /// Current model availability status.
    var modelAvailability: SystemLanguageModel.Availability {
        model.availability
    }

    // MARK: - Private Properties

    private let model = SystemLanguageModel.default
    private var activeSession: LanguageModelSession?
    private var activeThreadID: UUID?

    // MARK: - Session Management

    /// Creates a fresh session for the given thread.
    func resetSession(for threadID: UUID, systemInstructions: String? = nil) {
        if let instructions = systemInstructions, !instructions.isEmpty {
            activeSession = LanguageModelSession(instructions: instructions)
        } else {
            activeSession = LanguageModelSession()
        }
        activeThreadID = threadID
    }

    // MARK: - Generation

    /// Sends a prompt and streams the response, tracking TPS in real-time.
    ///
    /// Each iteration of the response stream is counted as one token for TPS estimation.
    /// The stream produces aggregated text (full text so far at each step).
    func sendMessage(
        prompt: String,
        threadID: UUID,
        systemInstructions: String? = nil,
        temperature: Double? = nil
    ) async throws -> GenerationResult {
        guard case .available = model.availability else {
            throw FoundationModelServiceError.modelUnavailable(
                "Apple Intelligence is not available on this device."
            )
        }

        // Lazily create or reuse session for this thread
        if activeSession == nil || activeThreadID != threadID {
            resetSession(for: threadID, systemInstructions: systemInstructions)
        }

        guard let session = activeSession else {
            throw FoundationModelServiceError.sessionNotAvailable
        }

        // Reset streaming state
        isGenerating = true
        streamingText = ""
        currentTPS = 0
        estimatedTokenCount = 0

        defer { isGenerating = false }

        let startTime = ContinuousClock.now
        var tokenCount = 0

        let options = GenerationOptions(temperature: temperature)
        let stream = session.streamResponse(to: prompt, options: options)

        for try await snapshot in stream {
            tokenCount += 1
            streamingText = snapshot.content
            estimatedTokenCount = tokenCount

            // Update TPS after a small warm-up to avoid noisy initial readings
            let elapsed = Self.durationToSeconds(ContinuousClock.now - startTime)
            if elapsed > 0.1 {
                currentTPS = Double(tokenCount) / elapsed
            }
        }

        let totalSeconds = Self.durationToSeconds(ContinuousClock.now - startTime)
        let finalTPS = totalSeconds > 0 ? Double(tokenCount) / totalSeconds : 0

        return GenerationResult(
            text: streamingText,
            tokenCount: tokenCount,
            tokensPerSecond: finalTPS,
            durationSeconds: totalSeconds
        )
    }

    /// Generates a short title for a conversation based on the first exchange.
    func generateTitle(for prompt: String, response: String) async -> String {
        do {
            let titleSession = LanguageModelSession(
                instructions: "Generate a concise title (3-6 words) for this conversation. Reply with ONLY the title text, nothing else."
            )
            let titlePrompt = "User said: \(prompt)\nAssistant replied: \(String(response.prefix(200)))"
            let result = try await titleSession.respond(to: titlePrompt)
            let raw = result.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = Self.stripMarkdown(raw)
            return title.isEmpty ? "New Chat" : String(title.prefix(50))
        } catch {
            return "New Chat"
        }
    }

    /// Regenerates a title based on the full conversation history.
    func regenerateTitle(for messages: [Message]) async -> String {
        do {
            let titleSession = LanguageModelSession(
                instructions: "Generate a concise title (3-6 words) for this conversation. Reply with ONLY the title text, nothing else."
            )

            // Build a summary from the conversation messages
            let summary = messages
                .sorted { $0.timestamp < $1.timestamp }
                .prefix(10)
                .map { msg in
                    let role = msg.role == .user ? "User" : "Assistant"
                    return "\(role): \(String(msg.content.prefix(150)))"
                }
                .joined(separator: "\n")

            let result = try await titleSession.respond(to: summary)
            let raw = result.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = Self.stripMarkdown(raw)
            return title.isEmpty ? "New Chat" : String(title.prefix(50))
        } catch {
            return "New Chat"
        }
    }

    // MARK: - Helpers

    /// Strips common Markdown formatting symbols from a title string.
    private static func stripMarkdown(_ text: String) -> String {
        var result = text
        // Remove heading markers
        result = result.replacingOccurrences(
            of: #"^#{1,6}\s+"#, with: "", options: .regularExpression
        )
        // Remove bold/italic markers (**, *, __, _)
        result = result.replacingOccurrences(
            of: #"[*_]{1,3}"#, with: "", options: .regularExpression
        )
        // Remove strikethrough markers (~~)
        result = result.replacingOccurrences(of: "~~", with: "")
        // Remove inline code backticks
        result = result.replacingOccurrences(of: "`", with: "")
        // Remove surrounding quotes
        result = result.replacingOccurrences(
            of: #"^["'"]+|["'"]+$"#, with: "", options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func durationToSeconds(_ duration: Duration) -> Double {
        let c = duration.components
        return Double(c.seconds) + Double(c.attoseconds) / 1_000_000_000_000_000_000
    }
}
