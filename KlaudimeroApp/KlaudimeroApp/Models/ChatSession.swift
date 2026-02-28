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
    var images: [String]
    let timestamp: Date?

    enum CodingKeys: String, CodingKey {
        case role, content, images, timestamp
    }

    init(role: String, content: String, images: [String] = []) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.images = images
        self.timestamp = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.role = try container.decode(String.self, forKey: .role)
        self.content = try container.decode(String.self, forKey: .content)
        self.images = (try? container.decode([String].self, forKey: .images)) ?? []
        self.timestamp = try? container.decode(Date.self, forKey: .timestamp)
    }
}

struct UploadResponse: Codable {
    let filePath: String
    let filename: String

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case filename
    }
}

struct ChatResponse: Codable {
    let response: String
}
