import SwiftUI
import MarkdownUI

/// Outer shell: resolves the ChatViewModel from ChatStore and hands it to the
/// inner view as an @ObservedObject so published-property changes trigger redraws.
struct ChatDetailView: View {
    @EnvironmentObject var api: APIClient
    @EnvironmentObject var chatStore: ChatStore
    let sessionId: String

    var body: some View {
        ChatDetailContentView(
            viewModel: chatStore.viewModel(for: sessionId, api: api)
        )
    }
}

/// Inner view that owns an @ObservedObject reference to the view model.
/// Because ChatViewModel lives in ChatStore, it is NOT deallocated on navigation —
/// isSending and session state persist and the loading indicator reappears on re-entry.
private struct ChatDetailContentView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var messageText = ""

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            inputBar
        }
        .navigationTitle(viewModel.session?.title.isEmpty == false ? viewModel.session!.title : "New Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSessionIfNeeded()
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let session = viewModel.session {
                        ForEach(session.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    if viewModel.isSending {
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
            .onChange(of: viewModel.session?.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isSending) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if viewModel.isSending {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let lastMessage = viewModel.session?.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private var sourceType: String? {
        viewModel.session?.sourceType
    }

    private var assistantBubbleColor: Color {
        switch sourceType {
        case "job": return Color.orange.opacity(0.12)
        case "heartbeat": return Color.pink.opacity(0.12)
        default: return Color(.systemGray6)
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(assistantBubbleColor)
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
                let content = messageText
                messageText = ""
                Task { await viewModel.sendMessage(content) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
