import SwiftUI

/// Sidebar showing chat thread list with search and compose button (Messages app style).
struct SidebarView: View {
    let threads: [ChatThread]
    @Binding var selectedThread: ChatThread?
    let onNewChat: () -> Void
    let onDeleteThread: (ChatThread) -> Void

    @State private var searchText = ""

    private var filteredThreads: [ChatThread] {
        if searchText.isEmpty { return threads }
        let query = searchText.lowercased()
        return threads.filter { thread in
            thread.title.lowercased().contains(query)
            || thread.messages.contains { $0.content.lowercased().contains(query) }
        }
    }

    var body: some View {
        List(selection: $selectedThread) {
            ForEach(filteredThreads) { thread in
                ThreadRow(thread: thread)
                    .tag(thread)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDeleteThread(thread)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            onDeleteThread(thread)
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: onNewChat) {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Chat")
            }
        }
        .navigationTitle("Foundation Studio")
    }
}

// MARK: - Thread Row

private struct ThreadRow: View {
    let thread: ChatThread

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(thread.title)
                .font(.headline)
                .lineLimit(1)

            if !thread.messages.isEmpty {
                Text("\(thread.messages.count) messages")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
