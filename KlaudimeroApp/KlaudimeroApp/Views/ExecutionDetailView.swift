import SwiftUI

struct ExecutionDetailView: View {
    let execution: Execution

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Status header
                HStack {
                    Text(execution.statusEmoji)
                        .font(.title)
                    Text(execution.status.capitalized)
                        .font(.title2.bold())
                    Spacer()
                    Text(execution.formattedDuration)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Metadata
                Group {
                    LabeledContent("Started", value: execution.startedAt.formatted())
                    if let finished = execution.finishedAt {
                        LabeledContent("Finished", value: finished.formatted())
                    }
                    if let exitCode = execution.exitCode {
                        LabeledContent("Exit Code", value: "\(exitCode)")
                    }
                }

                Divider()

                // Prompt
                Text("Prompt")
                    .font(.headline)
                Text(execution.prompt)
                    .font(.body.monospaced())
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Divider()

                // Output
                Text("Output")
                    .font(.headline)
                Text(execution.output.isEmpty ? "(no output)" : execution.output)
                    .font(.caption.monospaced())
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle("Execution")
        .navigationBarTitleDisplayMode(.inline)
    }
}
