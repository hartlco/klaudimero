import SwiftUI

struct JobDetailView: View {
    @EnvironmentObject var api: APIClient
    @State var job: Job
    @State private var executions: [Execution] = []
    @State private var isTriggering = false
    @State private var showingEdit = false

    var body: some View {
        List {
            Section("Configuration") {
                LabeledContent("Schedule", value: job.schedule)
                LabeledContent("Max Turns", value: "\(job.maxTurns)")
                LabeledContent("Enabled", value: job.enabled ? "Yes" : "No")
                LabeledContent("Notify On", value: job.notifyOn.joined(separator: ", "))
            }

            Section("Prompt") {
                Text(job.prompt)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }

            Section {
                Button {
                    Task { await triggerJob() }
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Trigger Now")
                    }
                }
                .disabled(isTriggering)
            }

            Section("Recent Executions") {
                if executions.isEmpty {
                    Text("No executions yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(executions) { execution in
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
                }
            }
        }
        .navigationTitle(job.name)
        .toolbar {
            Button("Edit") { showingEdit = true }
        }
        .refreshable { await loadExecutions() }
        .task { await loadExecutions() }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                JobFormView(mode: .edit(job)) { updatedJob in
                    if let updatedJob { self.job = updatedJob }
                }
            }
        }
    }

    private func loadExecutions() async {
        do {
            executions = try await api.listExecutions(jobId: job.id)
        } catch {
            print("Failed to load executions: \(error)")
        }
    }

    private func triggerJob() async {
        isTriggering = true
        do {
            _ = try await api.triggerJob(job.id)
            // Wait briefly then reload
            try await Task.sleep(for: .seconds(1))
            await loadExecutions()
        } catch {
            print("Failed to trigger job: \(error)")
        }
        isTriggering = false
    }
}
