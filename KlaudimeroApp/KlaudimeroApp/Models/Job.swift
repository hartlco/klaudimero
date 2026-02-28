import Foundation

struct Job: Codable, Identifiable {
    let id: String
    var name: String
    var prompt: String
    var schedule: String
    var enabled: Bool
    var maxTurns: Int
    var notifyOn: [String]
    var nextRun: Date?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, prompt, schedule, enabled
        case maxTurns = "max_turns"
        case notifyOn = "notify_on"
        case nextRun = "next_run"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct JobCreate: Codable {
    var name: String
    var prompt: String
    var schedule: String
    var enabled: Bool = true
    var maxTurns: Int = 50
    var notifyOn: [String] = ["completed", "failed"]

    enum CodingKeys: String, CodingKey {
        case name, prompt, schedule, enabled
        case maxTurns = "max_turns"
        case notifyOn = "notify_on"
    }
}

struct JobUpdate: Codable {
    var name: String?
    var prompt: String?
    var schedule: String?
    var enabled: Bool?
    var maxTurns: Int?
    var notifyOn: [String]?

    enum CodingKeys: String, CodingKey {
        case name, prompt, schedule, enabled
        case maxTurns = "max_turns"
        case notifyOn = "notify_on"
    }
}
