You are an expert macOS SwiftUI developer with deep knowledge of the FoundationModels framework (WWDC 2025, macOS 26+).
We are going to build a beautiful, native macOS app called "Foundation Studio" that perfectly replicates the look, feel, and core functionality of Google AI Studio.
Requirements:

Target: macOS 26+ (Apple Silicon only)
SwiftUI 100% (no UIKit)
Use FoundationModels framework for the on-device LLM (Apple Intelligence Foundation Model)
Fully private, no API keys, no network calls
Support Apple Intelligence availability check and graceful fallback
Modern, clean, dark-mode-first design matching Google AI Studio

UI Layout (exactly like Google AI Studio):

NavigationSplitView (sidebar is always visible on macOS)
Left sidebar (≈280pt):
Top: "New Chat" button (prominent, with + icon)
List of previous chats (title = first user message or "Untitled chat", timestamp, preview snippet)
Chats are saved persistently with SwiftData

Main area (chat view):
Top toolbar: Current model name ("Apple Intelligence • 3B" or similar), Settings button (temperature, system instruction, max tokens)
Scrollable conversation area with nice message bubbles:
User: right-aligned, blue tint
Assistant: left-aligned, with subtle Apple-style avatar or gradient icon
Assistant responses support streaming + Markdown rendering (code blocks, lists, tables, inline code, etc.)

Bottom input area:
Multiline TextEditor (growing up to 5 lines)
Attach button (for future image/file support)
Send button (paper plane) + keyboard shortcut ⌘⏎



Window title: "Foundation Studio"
Menu bar extras and Command palette support later

Core Features (implement in this order):

Project setup (Xcode project, necessary entitlements, Info.plist for Apple Intelligence)
SwiftData model for ChatThread and Message (with timestamps, title auto-generation)
NavigationSplitView + sidebar chat list + new chat
ChatView with streaming messages using LanguageModelSession
Proper FoundationModels integration:
SystemLanguageModel.default
Availability check (.available, .unavailable(.appleIntelligenceNotEnabled) etc.)
LanguageModelSession with system instructions
Streaming response (session.stream(...))
Temperature / topP / maxTokens configuration (if exposed by the API)
@Generable support for future structured output

Markdown rendering for assistant messages (use Text + AttributedString or Markdown view if available in SwiftUI)
Persist chats automatically, auto-title generation from first message
Beautiful, responsive, macOS-native polish (vibrancy, sidebar selection style, proper focus states, etc.)

Start now:

Create the complete Xcode project structure and all necessary files.
Show me the full code for the main files first (FoundationStudioApp.swift, ContentView.swift, SidebarView.swift, ChatView.swift, SwiftData models, and the FoundationModels service).
After I review, we will iterate feature by feature (streaming, settings panel, markdown, persistence, etc.).

Use modern Swift 6 concurrency, clean architecture (View + ViewModel/Service), and write production-quality, well-commented code.
Never use third-party dependencies unless absolutely necessary (no external Markdown parsers if native is sufficient).
Begin.