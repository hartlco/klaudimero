import SwiftUI

struct HeartbeatPromptEditView: View {
    @State var prompt: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TextEditor(text: $prompt)
            .font(.body.monospaced())
            .padding(4)
            .navigationTitle("Edit Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(prompt)
                        dismiss()
                    }
                }
            }
    }
}
