import SwiftUI
import MarkdownUI

struct ExecutionDetailView: View {
    let execution: Execution

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Status bar
                HStack {
                    Text(execution.statusEmoji)
                    Text(execution.status.capitalized)
                        .font(.subheadline.bold())
                    Spacer()
                    Text(execution.formattedDuration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Output — rendered as Markdown
                if execution.output.isEmpty {
                    Text("(no output)")
                        .foregroundStyle(.secondary)
                } else {
                    Markdown(execution.output)
                        .textSelection(.enabled)
                        .markdownTheme(.gitHub)
                }

                Divider()

                // Prompt
                DisclosureGroup("Prompt") {
                    Text(execution.prompt)
                        .font(.body.monospaced())
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.platformGray6)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Metadata
                DisclosureGroup("Details") {
                    VStack(spacing: 8) {
                        LabeledContent("Started", value: execution.startedAt.formatted())
                        if let finished = execution.finishedAt {
                            LabeledContent("Finished", value: finished.formatted())
                        }
                        if let exitCode = execution.exitCode {
                            LabeledContent("Exit Code", value: "\(exitCode)")
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Execution")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
