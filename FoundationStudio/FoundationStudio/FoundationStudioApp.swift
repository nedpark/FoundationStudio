import SwiftUI
import SwiftData

@main
struct FoundationStudioApp: App {
    @State private var modelService = FoundationModelService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(modelService)
        }
        .modelContainer(for: [ChatThread.self, Message.self, PromptRecord.self])
    }
}
