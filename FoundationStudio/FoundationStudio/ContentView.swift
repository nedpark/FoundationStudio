import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(FoundationModelService.self) private var modelService
    @Query(sort: \ChatThread.updatedAt, order: .reverse) private var threads: [ChatThread]

    @State private var selectedThread: ChatThread?
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                threads: threads,
                selectedThread: $selectedThread,
                onNewChat: createNewThread,
                onDeleteThread: deleteThread
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        } detail: {
            if let thread = selectedThread {
                ChatView(thread: thread)
            } else {
                ContentUnavailableView(
                    "Welcome to Foundation Studio",
                    systemImage: "brain",
                    description: Text("Create a new chat or select an existing one to get started.\nPowered by Apple Intelligence, 100% on-device.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                ModelStatusBadge()
            }
        }
        .onAppear {
            if selectedThread == nil {
                selectedThread = threads.first
            }
        }
    }

    // MARK: - Actions

    private func createNewThread() {
        let thread = ChatThread()
        modelContext.insert(thread)
        try? modelContext.save()
        selectedThread = thread
    }

    private func deleteThread(_ thread: ChatThread) {
        if selectedThread == thread {
            selectedThread = nil
        }
        modelContext.delete(thread)
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .environment(FoundationModelService())
        .modelContainer(for: [ChatThread.self, Message.self, PromptRecord.self], inMemory: true)
}
