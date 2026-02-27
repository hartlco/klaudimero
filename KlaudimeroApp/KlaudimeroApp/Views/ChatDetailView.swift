import SwiftUI
import MarkdownUI

struct ChatDetailView: View {
    @EnvironmentObject var api: APIClient
    let sessionId: String

    @State private var session: ChatSession?
    @State private var messageText = ""
    @State private var isSending = false
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            inputBar
        }
        .navigationTitle(session?.title.isEmpty == false ? session!.title : "New Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadSession() }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let session {
                        ForEach(session.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    if isSending {
                        HStack {
                            ProgressView()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            Spacer()
                        }
                        .id("loading")
                    }
                }
                .padding()
            }
            .onChange(of: session?.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: isSending) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if isSending {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let lastMessage = session?.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == "user" { Spacer(minLength: 40) }

            VStack(alignment: message.role == "user" ? .trailing : .leading) {
                if message.role == "user" {
                    Text(message.content)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Markdown(message.content)
                        .textSelection(.enabled)
                        .markdownTheme(.gitHub)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            if message.role == "assistant" { Spacer(minLength: 40) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func loadSession() async {
        isLoading = true
        do {
            session = try await api.getChatSession(sessionId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func sendMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        messageText = ""
        // Optimistically add user message
        session?.messages.append(ChatMessage(role: "user", content: content))

        isSending = true
        do {
            let response = try await api.sendChatMessage(sessionId: sessionId, content: content)
            session?.messages.append(ChatMessage(role: "assistant", content: response))
            // Update title if it was empty
            if session?.title.isEmpty == true {
                session?.title = String(content.prefix(50))
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
