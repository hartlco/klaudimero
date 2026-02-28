import Foundation

class APIClient: ObservableObject {
    @Published var baseURL: String {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: "serverURL")
        }
    }

    static let shared = APIClient()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // Try ISO8601 with fractional seconds
            let formatters: [ISO8601DateFormatter] = {
                let f1 = ISO8601DateFormatter()
                f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let f2 = ISO8601DateFormatter()
                f2.formatOptions = [.withInternetDateTime]
                return [f1, f2]
            }()
            for formatter in formatters {
                if let date = formatter.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private init() {
        self.baseURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:8585"
    }

    private func url(_ path: String) -> URL {
        URL(string: "\(baseURL)\(path)")!
    }

    private func request<T: Decodable>(_ method: String, _ path: String, body: (any Encodable)? = nil) async throws -> T {
        var req = URLRequest(url: url(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            req.httpBody = try encoder.encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let http = response as? HTTPURLResponse
            throw APIError.httpError(http?.statusCode ?? 0, String(data: data, encoding: .utf8) ?? "")
        }
        return try decoder.decode(T.self, from: data)
    }

    private func requestVoid(_ method: String, _ path: String, body: (any Encodable)? = nil) async throws {
        var req = URLRequest(url: url(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            req.httpBody = try encoder.encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let http = response as? HTTPURLResponse
            throw APIError.httpError(http?.statusCode ?? 0, String(data: data, encoding: .utf8) ?? "")
        }
    }

    // MARK: - Jobs

    func listJobs() async throws -> [Job] {
        try await request("GET", "/jobs")
    }

    func createJob(_ job: JobCreate) async throws -> Job {
        try await request("POST", "/jobs", body: job)
    }

    func getJob(_ id: String) async throws -> Job {
        try await request("GET", "/jobs/\(id)")
    }

    func updateJob(_ id: String, _ update: JobUpdate) async throws -> Job {
        try await request("PUT", "/jobs/\(id)", body: update)
    }

    func deleteJob(_ id: String) async throws {
        try await requestVoid("DELETE", "/jobs/\(id)")
    }

    func triggerJob(_ id: String) async throws -> [String: String] {
        try await request("POST", "/jobs/\(id)/trigger")
    }

    // MARK: - Executions

    func listExecutions(jobId: String) async throws -> [Execution] {
        try await request("GET", "/jobs/\(jobId)/executions")
    }

    func getExecution(_ id: String) async throws -> Execution {
        try await request("GET", "/executions/\(id)")
    }

    func getLatestExecution() async throws -> Execution {
        try await request("GET", "/executions/latest")
    }

    // MARK: - Heartbeat

    func getHeartbeat() async throws -> HeartbeatStatus {
        try await request("GET", "/heartbeat")
    }

    func updateHeartbeat(_ update: HeartbeatConfigUpdate) async throws -> HeartbeatStatus {
        try await request("PUT", "/heartbeat", body: update)
    }

    func listHeartbeatExecutions() async throws -> [Execution] {
        try await request("GET", "/heartbeat/executions")
    }

    func triggerHeartbeat() async throws -> [String: String] {
        try await request("POST", "/heartbeat/trigger")
    }

    // MARK: - Chat

    func listChatSessions() async throws -> [ChatSessionSummary] {
        try await request("GET", "/chat/sessions")
    }

    func createChatSession() async throws -> ChatSession {
        try await request("POST", "/chat/sessions")
    }

    func getChatSession(_ id: String) async throws -> ChatSession {
        try await request("GET", "/chat/sessions/\(id)")
    }

    func deleteChatSession(_ id: String) async throws {
        try await requestVoid("DELETE", "/chat/sessions/\(id)")
    }

    func sendChatMessage(sessionId: String, content: String, images: [String] = [], maxTurns: Int = 50) async throws -> String {
        struct Body: Codable {
            let content: String
            let max_turns: Int
            let images: [String]
        }
        let resp: ChatResponse = try await request("POST", "/chat/sessions/\(sessionId)/message", body: Body(content: content, max_turns: maxTurns, images: images))
        return resp.response
    }

    func uploadImage(sessionId: String, imageData: Data, filename: String) async throws -> UploadResponse {
        let boundary = UUID().uuidString
        var req = URLRequest(url: url("/chat/sessions/\(sessionId)/upload"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let http = response as? HTTPURLResponse
            throw APIError.httpError(http?.statusCode ?? 0, String(data: data, encoding: .utf8) ?? "")
        }
        return try decoder.decode(UploadResponse.self, from: data)
    }

    func uploadImageURL(filename: String) -> URL {
        url("/chat/uploads/\(filename)")
    }

    // MARK: - Devices

    func registerDevice(token: String, name: String?) async throws {
        struct Body: Codable { let token: String; let name: String? }
        let _: [String: String] = try await request("POST", "/devices", body: Body(token: token, name: name))
    }
}

enum APIError: LocalizedError {
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            return "HTTP \(code): \(body)"
        }
    }
}
