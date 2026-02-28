import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var api: APIClient
    @EnvironmentObject var chatStore: ChatStore
    @EnvironmentObject var navigationState: NavigationState
    @State private var sessions: [ChatSessionSummary] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var navigateToSessionId: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    NavigationLink(destination: ChatDetailView(sessionId: session.id)) {
                        HStack(spacing: 10) {
                            Image(systemName: iconName(for: session.sourceType))
                                .foregroundStyle(iconColor(for: session.sourceType))
                                .font(.title3)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title.isEmpty ? "New Chat" : session.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(session.updatedAt, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteSessions)
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await createSession() }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await loadSessions() }
            .task { await loadSessions() }
            .overlay {
                if isLoading && sessions.isEmpty {
                    ProgressView()
                }
                if let error, sessions.isEmpty {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                }
                if !isLoading && error == nil && sessions.isEmpty {
                    ContentUnavailableView("No Chats", systemImage: "bubble.left.and.bubble.right", description: Text("Tap + to start a conversation"))
                }
            }
            .navigationDestination(item: $navigateToSessionId) { sessionId in
                ChatDetailView(sessionId: sessionId)
            }
            .onAppear {
                if let sessionId = navigationState.pendingSessionId {
                    navigateToSessionId = sessionId
                    navigationState.pendingSessionId = nil
                }
            }
            .onChange(of: navigationState.pendingSessionId) { _, sessionId in
                if let sessionId {
                    navigateToSessionId = sessionId
                    navigationState.pendingSessionId = nil
                }
            }
        }
    }

    private func loadSessions() async {
        isLoading = true
        error = nil
        do {
            sessions = try await api.listChatSessions()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func createSession() async {
        do {
            let session = try await api.createChatSession()
            navigateToSessionId = session.id
            await loadSessions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func iconName(for sourceType: String?) -> String {
        switch sourceType {
        case "job": return "clock.arrow.circlepath"
        case "heartbeat": return "heart.circle"
        default: return "bubble.left"
        }
    }

    private func iconColor(for sourceType: String?) -> Color {
        switch sourceType {
        case "job": return .orange
        case "heartbeat": return .pink
        default: return .accentColor
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        let toDelete = offsets.map { sessions[$0] }
        sessions.remove(atOffsets: offsets)
        Task {
            for session in toDelete {
                try? await api.deleteChatSession(session.id)
                chatStore.remove(sessionId: session.id)
            }
        }
    }
}
