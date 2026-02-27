import SwiftUI

struct ExecutionListView: View {
    @EnvironmentObject var api: APIClient
    let jobId: String
    let jobName: String
    @State private var executions: [Execution] = []

    var body: some View {
        List(executions) { execution in
            NavigationLink(destination: ExecutionDetailView(execution: execution)) {
                HStack {
                    Text(execution.statusEmoji)
                    VStack(alignment: .leading) {
                        Text(execution.startedAt, style: .date)
                            + Text(" ")
                            + Text(execution.startedAt, style: .time)
                        Text(execution.formattedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Executions")
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        do {
            executions = try await api.listExecutions(jobId: jobId)
        } catch {
            print("Failed to load executions: \(error)")
        }
    }
}
