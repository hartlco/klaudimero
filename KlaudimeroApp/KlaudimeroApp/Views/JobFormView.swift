import SwiftUI

enum JobFormMode {
    case create
    case edit(Job)
}

struct JobFormView: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) var dismiss

    let mode: JobFormMode
    let onSave: (Job?) async -> Void

    @State private var name = ""
    @State private var prompt = ""
    @State private var schedule = ""
    @State private var enabled = true
    @State private var maxTurns = 50
    @State private var isSaving = false
    @State private var error: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String {
        isEditing ? "Edit Job" : "New Job"
    }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Name", text: $name)
                TextField("Schedule (cron or interval)", text: $schedule)
                    .autocapitalization(.none)
                Toggle("Enabled", isOn: $enabled)
                Stepper("Max Turns: \(maxTurns)", value: $maxTurns, in: 1...200)
            }

            Section("Prompt") {
                TextEditor(text: $prompt)
                    .frame(minHeight: 120)
                    .font(.body.monospaced())
            }

            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(name.isEmpty || prompt.isEmpty || schedule.isEmpty || isSaving)
            }
        }
        .onAppear {
            if case .edit(let job) = mode {
                name = job.name
                prompt = job.prompt
                schedule = job.schedule
                enabled = job.enabled
                maxTurns = job.maxTurns
            }
        }
    }

    private func save() async {
        isSaving = true
        error = nil
        do {
            if case .edit(let job) = mode {
                let update = JobUpdate(
                    name: name, prompt: prompt, schedule: schedule,
                    enabled: enabled, maxTurns: maxTurns
                )
                let updated = try await api.updateJob(job.id, update)
                await onSave(updated)
            } else {
                let create = JobCreate(
                    name: name, prompt: prompt, schedule: schedule,
                    enabled: enabled, maxTurns: maxTurns
                )
                let created = try await api.createJob(create)
                await onSave(created)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
