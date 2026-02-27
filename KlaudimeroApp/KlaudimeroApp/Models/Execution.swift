import Foundation

struct Execution: Codable, Identifiable {
    let id: String
    let jobId: String
    let startedAt: Date
    let finishedAt: Date?
    let status: String
    let prompt: String
    let output: String
    let exitCode: Int?
    let durationSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case jobId = "job_id"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case status, prompt, output
        case exitCode = "exit_code"
        case durationSeconds = "duration_seconds"
    }

    var statusEmoji: String {
        switch status {
        case "completed": return "✅"
        case "failed": return "❌"
        case "running": return "⏳"
        default: return "❓"
        }
    }

    var formattedDuration: String {
        guard let d = durationSeconds else { return "—" }
        if d < 60 { return String(format: "%.1fs", d) }
        let min = Int(d) / 60
        let sec = Int(d) % 60
        return "\(min)m \(sec)s"
    }
}
