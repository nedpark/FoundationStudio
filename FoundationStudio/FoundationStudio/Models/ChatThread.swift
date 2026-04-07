import Foundation
import SwiftData

/// Represents a conversation thread containing multiple messages.
/// Each thread has its own system instructions and associated prompt records.
@Model
final class ChatThread {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var systemInstructions: String?

    /// Temperature for generation (0.0 = deterministic, 1.0 = creative). Nil uses system default.
    var temperature: Double?

    @Relationship(deleteRule: .cascade, inverse: \Message.thread)
    var messages: [Message] = []

    @Relationship(deleteRule: .cascade, inverse: \PromptRecord.thread)
    var promptRecords: [PromptRecord] = []

    init(title: String = "New Chat", systemInstructions: String? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.systemInstructions = systemInstructions
    }

    /// Messages sorted chronologically by timestamp.
    var sortedMessages: [Message] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }
}
