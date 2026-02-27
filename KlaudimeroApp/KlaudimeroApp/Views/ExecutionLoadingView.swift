import SwiftUI

struct ExecutionLoadingView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) var dismiss
    let executionId: String

    @State private var execution: Execution?
    @State private var error: String?
    @State private var isPolling = true

    var body: some View {
        Group {
            if let execution {
                ExecutionDetailView(execution: execution)
            } else if let error {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading execution...")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task { await loadExecution() }
    }

    private func loadExecution() async {
        // Poll a few times in case the execution hasn't been written yet
        for attempt in 0..<10 {
            do {
                execution = try await api.getExecution(executionId)
                return
            } catch {
                if attempt < 9 {
                    try? await Task.sleep(for: .seconds(2))
                } else {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}
