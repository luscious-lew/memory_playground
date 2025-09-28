import Foundation
import OSLog

struct VoiceConversationService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case requestFailed(status: Int, message: String)
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Provide a Supabase API key to load voice conversations."
            case .invalidURL:
                return "Supabase URL could not be formed."
            case .requestFailed(let status, let message):
                return "Supabase request failed (status: \(status)): \(message)"
            case .decodingFailed:
                return "Supabase response could not be decoded."
            }
        }
    }

    private let apiKey: String
    private let projectRef: String
    private let session: URLSession
    private let logger = Logger(subsystem: "com.memoryplayground.app", category: "VoiceConversationService")

    private var restURL: URL? {
        URL(string: "https://\(projectRef).supabase.co/rest/v1")
    }

    init(apiKey: String, projectRef: String = "rxdqwtdhsqjpjvnvfnsp", session: URLSession = .shared) {
        self.apiKey = apiKey
        self.projectRef = projectRef
        self.session = session
    }

    func fetchLatestConversations(limit: Int = 50) async throws -> [VoiceConversationSummary] {
        guard let base = restURL else { throw ServiceError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("conversations"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,created_at,structured_title,structured_category,structured_emoji,structured_overview,status"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = components?.url else { throw ServiceError.invalidURL }
        return try await request(url: url)
    }

    func fetchConversationWithStats(id: UUID) async throws -> VoiceConversationSummary {
        guard let base = restURL else { throw ServiceError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("conversations"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(id.uuidString)"),
            URLQueryItem(name: "select", value: "id,created_at,structured_title,structured_category,structured_emoji,structured_overview,status"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components?.url else { throw ServiceError.invalidURL }
        let results: [VoiceConversationSummary] = try await request(url: url)
        guard let conversation = results.first else {
            throw ServiceError.decodingFailed
        }
        return conversation
    }

    func fetchSegments(for conversationID: UUID) async throws -> [VoiceSegment] {
        guard let base = restURL else { throw ServiceError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("conversation_segments"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "conversation_id", value: "eq.\(conversationID.uuidString)"),
            URLQueryItem(name: "order", value: "idx.asc"),
            URLQueryItem(name: "select", value: "idx,start_sec,end_sec,speaker,speaker_id,is_user,text")
        ]
        guard let url = components?.url else { throw ServiceError.invalidURL }
        return try await request(url: url)
    }

    func fetchPluginContent(for conversationID: UUID) async throws -> [String] {
        guard let base = restURL else { throw ServiceError.invalidURL }
        var components = URLComponents(url: base.appendingPathComponent("conversation_plugins"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "conversation_id", value: "eq.\(conversationID.uuidString)"),
            URLQueryItem(name: "select", value: "content")
        ]
        guard let url = components?.url else { throw ServiceError.invalidURL }
        struct PluginContent: Decodable { let content: String? }
        let rows: [PluginContent] = try await request(url: url)
        return rows.compactMap { $0.content?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed(status: -1, message: "Invalid HTTP response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Supabase request failed: status=\(httpResponse.statusCode) body=\(message, privacy: .public)")
            throw ServiceError.requestFailed(status: httpResponse.statusCode, message: message)
        }

        #if DEBUG
        if let string = String(data: data, encoding: .utf8) {
            logger.debug("Supabase raw response: \(string, privacy: .public)")
        }
        #endif

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(string)")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            if let string = String(data: data, encoding: .utf8) {
                logger.error("Failed to decode Supabase response: \(error.localizedDescription, privacy: .public). Payload: \(string, privacy: .public)")
            } else {
                logger.error("Failed to decode Supabase response: \(error.localizedDescription, privacy: .public)")
            }
            #else
            logger.error("Failed to decode Supabase response: \(error.localizedDescription, privacy: .public)")
            #endif
            throw ServiceError.decodingFailed
        }
    }
}
