import SwiftUI

/// Displays a single message bubble with role-based styling.
/// Assistant messages show generation metrics (TPS, token count, duration).
struct MessageBubbleView: View {
    let message: Message

    @State private var isHovering = false
    @State private var showCopied = false
    @State private var showRawText = false

    private var avatarIcon: String {
        switch message.role {
        case .user:      "person.circle.fill"
        case .assistant: "apple.intelligence"
        case .system:    "exclamationmark.triangle.fill"
        }
    }

    private var roleLabel: String {
        switch message.role {
        case .user:      "You"
        case .assistant: "Assistant"
        case .system:    "System"
        }
    }

    private var roleColor: Color {
        switch message.role {
        case .user:      .blue
        case .assistant: .purple
        case .system:    .orange
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar icon
            Image(systemName: avatarIcon)
                .font(.title3)
                .foregroundStyle(roleColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                // Header: role label + timestamp + action buttons
                HStack {
                    Text(roleLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(roleColor)

                    Spacer()

                    // Action buttons — fade in on hover
                    HStack(spacing: 12) {
                        // Markdown / Plain text toggle (assistant only)
                        if message.role == .assistant {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showRawText.toggle()
                                }
                            } label: {
                                Label(
                                    showRawText ? "Markdown" : "Plain",
                                    systemImage: "arrow.left.arrow.right"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }

                        Button {
                            copyToClipboard()
                        } label: {
                            Label(
                                showCopied ? "Copied" : "Copy",
                                systemImage: showCopied ? "checkmark" : "document.on.document"
                            )
                            .font(.caption)
                            .foregroundStyle(showCopied ? .green : .secondary)
                        }
                        .buttonStyle(.borderless)

                        ShareLink(item: message.content) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .opacity(isHovering || showCopied ? 1 : 0)

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Message content — Markdown or plain text
                if message.role == .assistant && !showRawText {
                    MarkdownContentView(text: message.content)
                } else if showRawText {
                    Text(message.content)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text(renderedContent)
                        .textSelection(.enabled)
                }

                // TPS badge for assistant messages
                if message.role == .assistant,
                   let tps = message.finalTokensPerSecond,
                   let tokenCount = message.tokenCount {
                    TPSBadge(
                        tps: tps,
                        tokenCount: tokenCount,
                        isStreaming: false,
                        duration: message.generationDurationSeconds
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            roleColor.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    /// Render message content as Markdown, falling back to plain text.
    private var renderedContent: AttributedString {
        (try? AttributedString(markdown: message.content)) ?? AttributedString(message.content)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)

        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }
}

// MARK: - TPS Badge

/// A compact badge showing generation speed metrics.
/// Used both during streaming (live) and on completed assistant messages.
struct TPSBadge: View {
    let tps: Double
    let tokenCount: Int
    let isStreaming: Bool
    var duration: Double? = nil

    var body: some View {
        HStack(spacing: 8) {
            if isStreaming {
                Image(systemName: "bolt.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse)
            }

            Text(tpsText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            if let duration {
                Text("·")
                    .foregroundStyle(.quaternary)
                Text(String(format: "%.1fs", duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text("·")
                .foregroundStyle(.quaternary)

            Text("\(tokenCount) tokens")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.3), in: Capsule())
        .contentTransition(.numericText(countsDown: false))
        .animation(.smooth(duration: 0.3), value: tps)
    }

    private var tpsText: String {
        if tps < 1 {
            return isStreaming ? "Starting..." : "< 1 TPS"
        }
        return String(format: "%.1f TPS", tps)
    }
}
