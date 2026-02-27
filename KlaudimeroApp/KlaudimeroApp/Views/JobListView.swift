import SwiftUI

struct JobListView: View {
    @EnvironmentObject var api: APIClient
    @State private var jobs: [Job] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingCreate = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(jobs) { job in
                    NavigationLink(destination: JobDetailView(job: job)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(job.name)
                                    .font(.headline)
                                Text(job.schedule)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !job.enabled {
                                Text("Disabled")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.secondary.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteJobs)
            }
            .navigationTitle("Klaudimero")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCreate = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable { await loadJobs() }
            .task { await loadJobs() }
            .overlay {
                if isLoading && jobs.isEmpty {
                    ProgressView()
                }
                if let error, jobs.isEmpty {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                }
            }
            .sheet(isPresented: $showingCreate) {
                NavigationStack {
                    JobFormView(mode: .create) { _ in
                        await loadJobs()
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }

    private func loadJobs() async {
        isLoading = true
        error = nil
        do {
            jobs = try await api.listJobs()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteJobs(at offsets: IndexSet) {
        let toDelete = offsets.map { jobs[$0] }
        jobs.remove(atOffsets: offsets)
        Task {
            for job in toDelete {
                try? await api.deleteJob(job.id)
            }
        }
    }
}
