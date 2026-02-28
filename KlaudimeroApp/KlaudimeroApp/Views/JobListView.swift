import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct JobListView: View {
    @EnvironmentObject var api: APIClient
    @EnvironmentObject var navigationState: NavigationState
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
                    .contextMenu {
                        Button {
                            Task {
                                try? await api.triggerJob(job.id)
                            }
                        } label: {
                            Label("Trigger Now", systemImage: "play.fill")
                        }
                        Button {
                            Task {
                                let update = JobUpdate(enabled: !job.enabled)
                                if let updated = try? await api.updateJob(job.id, update) {
                                    if let index = jobs.firstIndex(where: { $0.id == updated.id }) {
                                        jobs[index] = updated
                                    }
                                }
                            }
                        } label: {
                            Label(job.enabled ? "Disable" : "Enable", systemImage: job.enabled ? "pause.circle" : "play.circle")
                        }
                        Button {
                            copyToClipboard(job.prompt)
                        } label: {
                            Label("Copy Prompt", systemImage: "doc.on.doc")
                        }
                        Divider()
                        Button(role: .destructive) {
                            deleteJob(job)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteJobs)
            }
            .navigationTitle("Klaudimero")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .automatic) {
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
            .onChange(of: navigationState.pendingMenuAction) { _, action in
                guard navigationState.selectedTab == 1 else { return }
                switch action {
                case .newJob:
                    navigationState.pendingMenuAction = nil
                    showingCreate = true
                case .openSettings:
                    navigationState.pendingMenuAction = nil
                    showingSettings = true
                case .refresh:
                    navigationState.pendingMenuAction = nil
                    Task { await loadJobs() }
                default:
                    break
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

    private func deleteJob(_ job: Job) {
        jobs.removeAll { $0.id == job.id }
        Task {
            try? await api.deleteJob(job.id)
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
