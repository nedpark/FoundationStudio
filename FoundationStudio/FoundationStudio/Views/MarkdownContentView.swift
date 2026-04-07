import SwiftUI

// MARK: - Block Model

/// Represents a parsed Markdown block element.
enum MarkdownBlock: Identifiable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(language: String?, code: String)
    case unorderedList(items: [String])
    case orderedList(items: [(number: Int, text: String)])
    case blockquote(text: String)
    case horizontalRule

    var id: String {
        switch self {
        case .heading(_, let t):       "h-\(t.hashValue)"
        case .paragraph(let t):        "p-\(t.hashValue)"
        case .codeBlock(_, let c):     "cb-\(c.hashValue)"
        case .unorderedList(let i):    "ul-\(i.hashValue)"
        case .orderedList(let i):      "ol-\(i.map(\.text).hashValue)"
        case .blockquote(let t):       "bq-\(t.hashValue)"
        case .horizontalRule:          "hr-\(UUID().uuidString)"
        }
    }
}

// MARK: - Parser

enum MarkdownParser {
    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // --- Fenced code block ---
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(
                    language: lang.isEmpty ? nil : lang,
                    code: codeLines.joined(separator: "\n")
                ))
                continue
            }

            // --- Horizontal rule (---, ***, ___) ---
            if isHorizontalRule(trimmed) {
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // --- Heading ---
            if trimmed.hasPrefix("#") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                if level <= 6 {
                    let afterHashes = trimmed.dropFirst(level)
                    if afterHashes.isEmpty || afterHashes.first == " " {
                        let text = afterHashes
                            .trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: #"\s+#+\s*$"#, with: "", options: .regularExpression)
                        blocks.append(.heading(level: level, text: text))
                        i += 1
                        continue
                    }
                }
            }

            // --- Blockquote ---
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix("> ") {
                        quoteLines.append(String(l.dropFirst(2)))
                    } else if l == ">" {
                        quoteLines.append("")
                    } else if l.isEmpty || !l.hasPrefix(">") {
                        break
                    }
                    i += 1
                }
                blocks.append(.blockquote(text: quoteLines.joined(separator: "\n")))
                continue
            }

            // --- Unordered list ---
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                var items: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix("- ") {
                        items.append(String(l.dropFirst(2)))
                    } else if l.hasPrefix("* ") && !isHorizontalRule(l) {
                        items.append(String(l.dropFirst(2)))
                    } else if l.hasPrefix("+ ") {
                        items.append(String(l.dropFirst(2)))
                    } else if !l.isEmpty && !l.hasPrefix("#") && !l.hasPrefix("```") && !l.hasPrefix(">") {
                        // Continuation line
                        if !items.isEmpty {
                            items[items.count - 1] += " " + l
                        }
                    } else {
                        break
                    }
                    i += 1
                }
                blocks.append(.unorderedList(items: items))
                continue
            }

            // --- Ordered list ---
            if trimmed.range(of: #"^\d+[.)]\s"#, options: .regularExpression) != nil {
                var items: [(number: Int, text: String)] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    if let m = l.range(of: #"^(\d+)[.)]\s"#, options: .regularExpression) {
                        let numStr = l[l.startIndex..<l.firstIndex(where: { !$0.isNumber })!]
                        let num = Int(numStr) ?? (items.count + 1)
                        items.append((number: num, text: String(l[m.upperBound...])))
                    } else if !l.isEmpty && l.range(of: #"^[\-\*\+#>`]"#, options: .regularExpression) == nil {
                        if !items.isEmpty {
                            items[items.count - 1].text += " " + l
                        }
                    } else {
                        break
                    }
                    i += 1
                }
                blocks.append(.orderedList(items: items))
                continue
            }

            // --- Empty line ---
            if trimmed.isEmpty {
                i += 1
                continue
            }

            // --- Paragraph (default) ---
            var paragraphLines: [String] = []
            while i < lines.count {
                let l = lines[i]
                let lt = l.trimmingCharacters(in: .whitespaces)
                if lt.isEmpty
                    || lt.hasPrefix("#")
                    || lt.hasPrefix("```")
                    || lt.hasPrefix(">")
                    || isListStart(lt)
                    || isHorizontalRule(lt)
                {
                    break
                }
                paragraphLines.append(l)
                i += 1
            }
            if !paragraphLines.isEmpty {
                blocks.append(.paragraph(text: paragraphLines.joined(separator: "\n")))
            }
        }
        return blocks
    }

    // MARK: Helpers

    private static func isHorizontalRule(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        guard stripped.count >= 3 else { return false }
        return stripped.allSatisfy({ $0 == "-" })
            || stripped.allSatisfy({ $0 == "*" })
            || stripped.allSatisfy({ $0 == "_" })
    }

    private static func isListStart(_ line: String) -> Bool {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return true
        }
        return line.range(of: #"^\d+[.)]\s"#, options: .regularExpression) != nil
    }
}

// MARK: - Markdown Content View

/// Renders Markdown text with proper block-level formatting:
/// headings, code blocks, lists, blockquotes, and paragraphs with inline markup.
struct MarkdownContentView: View {
    let text: String

    private var blocks: [MarkdownBlock] {
        MarkdownParser.parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
    }

    // MARK: Block Dispatch

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            headingView(level: level, text: text)
        case .paragraph(let text):
            inlineMarkdownText(text)
                .textSelection(.enabled)
        case .codeBlock(let language, let code):
            codeBlockView(language: language, code: code)
        case .unorderedList(let items):
            unorderedListView(items: items)
        case .orderedList(let items):
            orderedListView(items: items)
        case .blockquote(let text):
            blockquoteView(text: text)
        case .horizontalRule:
            Divider()
                .padding(.vertical, 4)
        }
    }

    // MARK: Heading

    private func headingView(level: Int, text: String) -> some View {
        inlineMarkdownText(text)
            .font(headingFont(level))
            .fontWeight(.bold)
            .padding(.top, level <= 2 ? 6 : 2)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1:  .title
        case 2:  .title2
        case 3:  .title3
        case 4:  .headline
        default: .subheadline
        }
    }

    // MARK: Code Block

    private func codeBlockView(language: String?, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language label + copy button
            HStack {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                CodeCopyButton(code: code)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.windowBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary, lineWidth: 1))
    }

    // MARK: Unordered List

    private func unorderedListView(items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\u{2022}")
                        .foregroundStyle(.secondary)
                    inlineMarkdownText(item)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.leading, 4)
    }

    // MARK: Ordered List

    private func orderedListView(items: [(number: Int, text: String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(item.number).")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(minWidth: 20, alignment: .trailing)
                    inlineMarkdownText(item.text)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.leading, 4)
    }

    // MARK: Blockquote

    private func blockquoteView(text: String) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.purple.opacity(0.5))
                .frame(width: 3)

            inlineMarkdownText(text)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.leading, 12)
                .padding(.vertical, 4)
        }
        .padding(.leading, 4)
    }

    // MARK: Inline Markdown

    private func inlineMarkdownText(_ text: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(text)
    }
}

// MARK: - Code Copy Button

private struct CodeCopyButton: View {
    let code: String
    @State private var showCopied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showCopied = false }
            }
        } label: {
            Label(
                showCopied ? "Copied" : "Copy",
                systemImage: showCopied ? "checkmark" : "doc.on.doc"
            )
            .font(.caption2)
            .foregroundStyle(showCopied ? .green : .secondary)
        }
        .buttonStyle(.borderless)
    }
}
