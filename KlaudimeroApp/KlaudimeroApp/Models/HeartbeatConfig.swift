import Foundation

struct HeartbeatStatus: Codable {
    var enabled: Bool
    var intervalMinutes: Int
    var maxTurns: Int
    var prompt: String

    enum CodingKeys: String, CodingKey {
        case enabled, prompt
        case intervalMinutes = "interval_minutes"
        case maxTurns = "max_turns"
    }
}

struct HeartbeatConfigUpdate: Codable {
    var enabled: Bool?
    var intervalMinutes: Int?
    var maxTurns: Int?
    var prompt: String?

    enum CodingKeys: String, CodingKey {
        case enabled, prompt
        case intervalMinutes = "interval_minutes"
        case maxTurns = "max_turns"
    }
}
