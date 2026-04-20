import SwiftUI
import SwiftData

/// Main chat area displaying messages, streaming responses, and input.
struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(FoundationModelService.self) private var modelService

    @Bindable var thread: ChatThread

    @State private var inputText = ""
    @State private var isSystemInstructionsExpanded = false
    @State private var isRegeneratingTitle = false


    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(thread.sortedMessages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }

                    // Streaming response in progress
                    if modelService.isGenerating {
                        StreamingMessageView()
                            .id("streaming")
                    }
                }
                .padding()
            }
            .defaultScrollAnchor(.bottom)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaInset(edge: .top, spacing: 0) {
                // Collapsible system instructions editor
                if isSystemInstructionsExpanded {
                    SystemInstructionsEditor(
                        instructions: Binding(
                            get: { thread.systemInstructions ?? "" },
                            set: { thread.systemInstructions = $0.isEmpty ? nil : $0 }
                        ),
                        temperature: $thread.temperature
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Input overlays the scroll area with Liquid Glass see-through
                MessageInputView(
                    text: $inputText,
                    isGenerating: modelService.isGenerating,
                    onSend: sendMessage
                )
            }
            .onChange(of: thread.id) {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: thread.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: modelService.streamingText) {
                scrollToBottom(proxy: proxy)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    regenerateTitle()
                } label: {
                    Label(
                        "Regenerate Title",
                        systemImage: "arrow.trianglehead.2.clockwise"
                    )
                }
                .help("Regenerate chat title")
                .disabled(isRegeneratingTitle || thread.messages.isEmpty)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation {
                        isSystemInstructionsExpanded.toggle()
                    }
                } label: {
                    Label(
                        "System Instructions",
                        systemImage: isSystemInstructionsExpanded
                            ? "chevron.up.circle.fill"
                            : "gear"
                    )
                }
                .help("Toggle system instructions")
            }
        }
        .navigationTitle(thread.title)
    }

    // MARK: - Regenerate Title

    private func regenerateTitle() {
        isRegeneratingTitle = true
        Task {
            let title = await modelService.regenerateTitle(for: thread.messages)
            thread.title = title
            thread.updatedAt = Date()
            try? modelContext.save()
            isRegeneratingTitle = false
        }
    }

    // MARK: - Send Message

    private func sendMessage() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        inputText = ""

        // Persist user message
        let userMessage = Message(role: .user, content: prompt)
        userMessage.thread = thread
        modelContext.insert(userMessage)
        thread.updatedAt = Date()

        // Persist prompt record
        let record = PromptRecord(
            promptText: prompt,
            systemInstructions: thread.systemInstructions,
            temperature: thread.temperature
        )
        record.thread = thread
        modelContext.insert(record)
        try? modelContext.save()

        // Generate assistant response
        Task {
            do {
                let result = try await modelService.sendMessage(
                    prompt: prompt,
                    threadID: thread.id,
                    systemInstructions: thread.systemInstructions,
                    temperature: thread.temperature
                )

                // Persist assistant message with generation metrics
                let assistantMessage = Message(
                    role: .assistant,
                    content: result.text,
                    tokenCount: result.tokenCount,
                    finalTokensPerSecond: result.tokensPerSecond,
                    generationDurationSeconds: result.durationSeconds
                )
                assistantMessage.thread = thread
                modelContext.insert(assistantMessage)

                // Update prompt record with response data
                record.responseText = result.text
                record.responseTokenCount = result.tokenCount
                record.tokensPerSecond = result.tokensPerSecond
                record.generationDurationSeconds = result.durationSeconds

                thread.updatedAt = Date()
                try? modelContext.save()

                // Auto-generate title for new conversations
                if thread.title == "New Chat" && thread.messages.count <= 2 {
                    let title = await modelService.generateTitle(
                        for: prompt,
                        response: result.text
                    )
                    thread.title = title
                    try? modelContext.save()
                }

            } catch {
                let errorText: String
                if "\(error)".contains("exceededContextWindowSize") {
                    errorText = "Context window limit reached. Please start a new chat to continue the conversation."
                } else {
                    errorText = error.localizedDescription
                }
                let systemMessage = Message(role: .system, content: errorText)
                systemMessage.thread = thread
                modelContext.insert(systemMessage)
                thread.updatedAt = Date()
                try? modelContext.save()
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        let action = {
            if modelService.isGenerating {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let lastMessage = thread.sortedMessages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
        if animated {
            withAnimation(.easeOut(duration: 0.2), action)
        } else {
            action()
        }
    }
}

// MARK: - System Instructions Editor

private struct SystemInstructionsEditor: View {
    @Binding var instructions: String
    @Binding var temperature: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Settings")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $instructions)
                .font(.body)
                .frame(height: 80)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if instructions.isEmpty {
                        Text("System instructions...")
                            .foregroundStyle(.quaternary)
                            .padding(.leading, 12)
                            .padding(.top, 12)
                            .allowsHitTesting(false)
                    }
                }

            // Temperature slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Temperature")
                        .font(.subheadline)
                    Spacer()
                    Text(temperatureLabel)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text("Precise")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Slider(
                        value: Binding(
                            get: { temperature ?? 0.5 },
                            set: { temperature = $0 }
                        ),
                        in: 0...1,
                        step: 0.05
                    )
                    Text("Creative")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if temperature != nil {
                    Button("Reset to Default") {
                        temperature = nil
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding()
        .background(.bar)
    }

    private var temperatureLabel: String {
        guard let t = temperature else { return "Default" }
        return String(format: "%.2f", t)
    }
}

// MARK: - Streaming Message View

private struct StreamingMessageView: View {
    @Environment(FoundationModelService.self) private var modelService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "apple.intelligence")
                    .font(.title3)
                    .foregroundStyle(.purple)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 6) {
                    if modelService.streamingText.isEmpty {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Thinking...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        MarkdownContentView(text: modelService.streamingText)
                    }

                    // Real-time TPS badge
                    TPSBadge(
                        tps: modelService.currentTPS,
                        tokenCount: modelService.estimatedTokenCount,
                        isStreaming: true
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

}


