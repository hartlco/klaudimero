import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) var dismiss
    @State private var serverURL: String = ""

    var body: some View {
        Form {
            Section("Server") {
                TextField("Server URL", text: $serverURL)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                Text("e.g. http://martins-machine:8585")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    api.baseURL = serverURL
                    dismiss()
                }
            }
        }
        .onAppear {
            serverURL = api.baseURL
        }
    }
}
