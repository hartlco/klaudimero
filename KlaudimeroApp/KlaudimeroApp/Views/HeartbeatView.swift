import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct HeartbeatView: View {
    @EnvironmentObject var api: APIClient
    @EnvironmentObject var navigationState: NavigationState
    @State private var status: HeartbeatStatus?
    @State private var executions: [Execution] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var isTriggering = false

    private let intervalOptions = [10, 30, 60]

    var body: some View {
        NavigationStack {
            List {
                if let status {
                    configSection(status)
                    promptSection(status)
                    triggerSection
                }
                executionsSection
            }
            .navigationTitle("Heartbeat")
            .refreshable { await load() }
            .task { await load() }
            .overlay {
                if isLoading && status == nil {
                    ProgressView()
                }
                if let error, status == nil {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                }
            }
            .onChange(of: navigationState.pendingMenuAction) { _, action in
                guard navigationState.selectedTab == 2 else { return }
                switch action {
                case .refresh:
                    navigationState.pendingMenuAction = nil
                    Task { await load() }
                default:
                    break
                }
            }
        }
    }

    private func configSection(_ status: HeartbeatStatus) -> some View {
        Section("Configuration") {
            Toggle("Enabled", isOn: Binding(
                get: { status.enabled },
                set: { newValue in
                    Task { await update(HeartbeatConfigUpdate(enabled: newValue)) }
                }
            ))

            Picker("Interval", selection: Binding(
                get: { status.intervalMinutes },
                set: { newValue in
                    Task { await update(HeartbeatConfigUpdate(intervalMinutes: newValue)) }
                }
            )) {
                ForEach(intervalOptions, id: \.self) { minutes in
                    Text("\(minutes) min").tag(minutes)
                }
            }

            Stepper("Max turns: \(status.maxTurns)", value: Binding(
                get: { status.maxTurns },
                set: { newValue in
                    Task { await update(HeartbeatConfigUpdate(maxTurns: newValue)) }
                }
            ), in: 5...200, step: 5)
        }
    }

    private func promptSection(_ status: HeartbeatStatus) -> some View {
        Section("Prompt") {
            NavigationLink(destination: HeartbeatPromptEditView(
                prompt: status.prompt,
                onSave: { newPrompt in
                    Task { await update(HeartbeatConfigUpdate(prompt: newPrompt)) }
                }
            )) {
                Text(status.prompt.prefix(100) + (status.prompt.count > 100 ? "..." : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private var triggerSection: some View {
        Section {
            Button {
                Task { await triggerNow() }
            } label: {
                HStack {
                    Spacer()
                    if isTriggering {
                        ProgressView()
                    } else {
                        Label("Trigger Now", systemImage: "play.fill")
                    }
                    Spacer()
                }
            }
            .disabled(isTriggering)
        }
    }

    private var executionsSection: some View {
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
                    .contextMenu {
                        Button {
                            copyToClipboard(execution.output)
                        } label: {
                            Label("Copy Output", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
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

    private func load() async {
        isLoading = true
        error = nil
        do {
            async let s = api.getHeartbeat()
            async let e = api.listHeartbeatExecutions()
            status = try await s
            executions = try await e
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func update(_ update: HeartbeatConfigUpdate) async {
        do {
            status = try await api.updateHeartbeat(update)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func triggerNow() async {
        isTriggering = true
        do {
            _ = try await api.triggerHeartbeat()
            try await Task.sleep(for: .seconds(1))
            await load()
        } catch {
            self.error = error.localizedDescription
        }
        isTriggering = false
    }
}
