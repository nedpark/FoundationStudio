import SwiftUI

/// Multi-line message input area with send button and ⌘⏎ shortcut.
/// Styled with Liquid Glass to match macOS Messages app.
struct MessageInputView: View {
    @Binding var text: String
    let isGenerating: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool
    @State private var measuredHeight: CGFloat = 20

    /// Single line height matching .body font on macOS.
    private let lineHeight: CGFloat = 20
    /// Maximum visible height (5 lines).
    private var maxHeight: CGFloat { lineHeight * 5 }

    var body: some View {
        GlassEffectContainer {
            HStack(alignment: .bottom, spacing: 8) {
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(height: min(max(measuredHeight, lineHeight), maxHeight))
                    .focused($isFocused)
                    .background(
                        // Hidden mirror text to measure actual wrapped content height
                        Text(text.isEmpty ? " " : text)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 5)
                            .opacity(0)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onChange(of: geometry.size.height, initial: true) { _, newHeight in
                                            measuredHeight = newHeight
                                        }
                                }
                            )
                    )
                    .animation(.easeOut(duration: 0.15), value: measuredHeight)
                    .onKeyPress(.return, phases: .down) { press in
                        // Shift+Enter → new line (let TextEditor handle it)
                        if press.modifiers.contains(.shift) {
                            return .ignored
                        }
                        // Enter → send message
                        if canSend {
                            onSend()
                            return .handled
                        }
                        return .ignored
                    }

                Button(action: onSend) {
                    Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(canSend ? .blue : .secondary)
                }
                .buttonStyle(.borderless)
                .disabled(!canSend)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Send message (⏎ or ⌘⏎)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onAppear { isFocused = true }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }
}
