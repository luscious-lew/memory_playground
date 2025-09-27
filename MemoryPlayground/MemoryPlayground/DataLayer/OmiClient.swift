import Foundation

/// Fetches transcripts from the Omi API. Supply an API key via the initializer.
struct OmiClient {
    struct Transcript: Decodable {
        struct Utterance: Decodable {
            let speaker: String?
            let text: String
            let startedAt: Date?
        }

        let id: String
        let startedAt: Date
        let speaker: String?
        let text: String?
        let utterances: [Utterance]?
        let entries: [Utterance]?
    }

    enum OmiError: LocalizedError {
        case missingAPIKey
        case requestFailed(status: Int, message: String)
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Add your Omi API key in the app settings before running ingestion."
            case .requestFailed(let status, let message):
                return "Omi API request failed (status: \(status)): \(message)"
            case .decodingFailed:
                return "Could not decode Omi transcripts. Verify the API response structure."
            }
        }
    }

    private let apiKey: String?
    private let baseURL: URL
    private let session: URLSession

    init(apiKey: String?, baseURL: URL = URL(string: "https://api.omi.me/v1")!, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = session
    }

    func fetchRecentTranscripts(limit: Int) async throws -> [ConversationItem] {
        guard let apiKey else { throw OmiError.missingAPIKey }

        var components = URLComponents(url: baseURL.appendingPathComponent("transcripts"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "order", value: "desc")
        ]

        guard let url = components?.url else {
            throw OmiError.requestFailed(status: -1, message: "Invalid URL components")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OmiError.requestFailed(status: -1, message: "No HTTP response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OmiError.requestFailed(status: httpResponse.statusCode, message: body)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        struct ResponseEnvelope: Decodable {
            let data: [Transcript]
        }

        let envelope: ResponseEnvelope
        do {
            envelope = try decoder.decode(ResponseEnvelope.self, from: data)
        } catch {
            throw OmiError.decodingFailed
        }

        return envelope.data
            .sorted { $0.startedAt < $1.startedAt }
            .flatMap { transcript in
                let utterances = transcript.utterances ?? transcript.entries
                if let utterances, !utterances.isEmpty {
                    return utterances.compactMap { utterance -> ConversationItem? in
                        let spoken = utterance.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !spoken.isEmpty else { return nil }
                        let timestamp = utterance.startedAt ?? transcript.startedAt
                        return ConversationItem(
                            timestamp: timestamp,
                            speaker: utterance.speaker ?? transcript.speaker ?? "Omi",
                            text: spoken,
                            source: .omi,
                            participantIdentifier: utterance.speaker
                        )
                    }
                }

                let spoken = (transcript.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !spoken.isEmpty else { return [] }
                return [ConversationItem(
                    timestamp: transcript.startedAt,
                    speaker: transcript.speaker ?? "Omi",
                    text: spoken,
                    source: .omi,
                    participantIdentifier: transcript.speaker
                )]
            }
    }
}
