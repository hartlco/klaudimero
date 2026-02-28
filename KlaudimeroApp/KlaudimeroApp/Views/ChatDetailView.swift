import SwiftUI
import PhotosUI
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
    @EnvironmentObject var api: APIClient
    @ObservedObject var viewModel: ChatViewModel
    @State private var messageText = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImageData: [(Data, String)] = []
    @State private var showCamera = false
    @State private var showPhotosPicker = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            if !selectedImageData.isEmpty {
                imagePreviewBar
                Divider()
            }
            inputBar
        }
        .navigationTitle(viewModel.session?.title.isEmpty == false ? viewModel.session!.title : "New Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSessionIfNeeded()
        }
        .onChange(of: selectedPhotos) { _, newItems in
            Task {
                for (index, item) in newItems.enumerated() {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let resized = Self.resizeImageData(data, maxDimension: 1500) {
                        selectedImageData.append((resized, "image_\(selectedImageData.count + index).jpg"))
                    }
                }
                selectedPhotos = []
            }
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotos, maxSelectionCount: 4, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let resized = Self.resizeImageData(image, maxDimension: 1500) {
                    selectedImageData.append((resized, "photo_\(selectedImageData.count).jpg"))
                }
            }
            .ignoresSafeArea()
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
                if !message.images.isEmpty {
                    imageGrid(for: message)
                }

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

                if let timestamp = message.timestamp {
                    Text(timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if message.role == "assistant" { Spacer(minLength: 40) }
        }
    }

    private func imageGrid(for message: ChatMessage) -> some View {
        HStack(spacing: 4) {
            ForEach(message.images, id: \.self) { imagePath in
                let filename = (imagePath as NSString).lastPathComponent
                let imageURL = api.uploadImageURL(filename: filename)
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray4))
                            .frame(width: 120, height: 120)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(width: 120, height: 120)
                            .overlay { ProgressView() }
                    }
                }
            }
        }
    }

    private var imagePreviewBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedImageData.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        if let uiImage = UIImage(data: selectedImageData[index].0) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Button {
                            selectedImageData.remove(at: index)
                            selectedPhotos = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.6)))
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private static func resizeImageData(_ data: Data, maxDimension: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return resizeImageData(image, maxDimension: maxDimension)
    }

    private static func resizeImageData(_ image: UIImage, maxDimension: CGFloat) -> Data? {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return image.jpegData(compressionQuality: 0.8)
        }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Menu {
                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
                Button {
                    showPhotosPicker = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle.angled")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            TextField("Message", text: $messageText, axis: .vertical)
                .focused($isInputFocused)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                let content = messageText
                let images = selectedImageData
                isInputFocused = false
                messageText = ""
                selectedImageData = []
                selectedPhotos = []
                Task { await viewModel.sendMessage(content, imageDataItems: images) }
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

private struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss, onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let dismiss: DismissAction
        let onCapture: (UIImage) -> Void

        init(dismiss: DismissAction, onCapture: @escaping (UIImage) -> Void) {
            self.dismiss = dismiss
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
