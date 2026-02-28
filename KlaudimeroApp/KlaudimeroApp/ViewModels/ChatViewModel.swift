import Foundation

@MainActor
class ChatViewModel: ObservableObject {
    @Published var session: ChatSession?
    @Published var isSending = false
    @Published var isLoading = false
    @Published var error: String?

    let sessionId: String
    private let api: APIClient

    init(sessionId: String, api: APIClient) {
        self.sessionId = sessionId
        self.api = api
    }

    func loadSessionIfNeeded() async {
        guard session == nil && !isLoading else { return }
        await loadSession()
    }

    func loadSession() async {
        isLoading = true
        do {
            session = try await api.getChatSession(sessionId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func sendMessage(_ content: String) async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        // Optimistically add user message
        session?.messages.append(ChatMessage(role: "user", content: trimmed))

        isSending = true
        do {
            let response = try await api.sendChatMessage(sessionId: sessionId, content: trimmed)
            session?.messages.append(ChatMessage(role: "assistant", content: response))
            // Update title from first user message if still empty
            if session?.title.isEmpty == true {
                session?.title = String(trimmed.prefix(50))
            }
        } catch {
            self.error = error.localizedDescription
            // Remove the optimistic user message on failure
            if session?.messages.last?.role == "user" {
                session?.messages.removeLast()
            }
        }
        isSending = false
    }
}
