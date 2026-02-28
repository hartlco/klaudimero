import Foundation

/// Keeps ChatViewModel instances alive across navigation so that pending
/// responses and loading state are preserved when the user navigates away
/// from and back into a chat session.
@MainActor
class ChatStore: ObservableObject {
    static let shared = ChatStore()

    private var viewModels: [String: ChatViewModel] = [:]

    private init() {}

    func viewModel(for sessionId: String, api: APIClient) -> ChatViewModel {
        if let existing = viewModels[sessionId] {
            return existing
        }
        let vm = ChatViewModel(sessionId: sessionId, api: api)
        viewModels[sessionId] = vm
        return vm
    }

    func remove(sessionId: String) {
        viewModels.removeValue(forKey: sessionId)
    }
}
