import Foundation

struct ChatSession: Codable, Identifiable {
    let id: String
    var title: String
    var messages: [ChatMessage]
    var sourceType: String?
    var sourceId: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, messages
        case sourceType = "source_type"
        case sourceId = "source_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ChatSessionSummary: Codable, Identifiable {
    let id: String
    var title: String
    var sourceType: String?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title
        case sourceType = "source_type"
        case updatedAt = "updated_at"
    }
}

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let role: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case role, content
    }

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.role = try container.decode(String.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
    }
}

struct ChatResponse: Codable {
    let response: String
}
