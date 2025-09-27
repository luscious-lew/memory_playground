import Foundation
import os

/// Wraps the OpenAI Responses API for GPT-5 access.
struct GPTClient {
    enum GPTError: LocalizedError {
        case missingAPIKey
        case requestFailed(status: Int, message: String)
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Provide a GPT-5 API key in the RemixEngine configuration."
            case .requestFailed(let status, let message):
                return "GPT-5 request failed (status: \(status)): \(message)"
            case .decodingFailed:
                return "GPT-5 response could not be decoded. Verify the API schema."
            }
        }
    }

    enum ReasoningEffort: String {
        case minimal
        case low
        case medium
        case high
    }

    enum TextVerbosity: String {
        case low
        case medium
        case high
    }

    private let apiKey: String?
    private let organizationID: String?
    private let projectID: String?
    private let session: URLSession
    private let baseURL: URL
    private let model: String
    private let logger = Logger(subsystem: "com.memoryplayground.app", category: "GPTClient")

    init(apiKey: String?,
         organizationID: String? = nil,
         projectID: String? = nil,
         model: String = "gpt-5",
         baseURL: URL = URL(string: "https://api.openai.com/v1")!,
         session: URLSession = .shared) {
        self.apiKey = apiKey
        self.organizationID = organizationID
        self.projectID = projectID
        self.session = session
        self.baseURL = baseURL
        self.model = model
    }

    func complete(prompt: String,
                  instructions: String?,
                  reasoningEffort: ReasoningEffort? = nil,
                  textVerbosity: TextVerbosity? = nil,
                  maxTokens: Int? = nil,
                  store: Bool? = nil) async throws -> String {
        guard let apiKey else {
            logger.error("OPENAI_API_KEY is missing; aborting GPT-5 call.")
            throw GPTError.missingAPIKey
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("responses"))
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let organizationID, !organizationID.isEmpty {
            request.addValue(organizationID, forHTTPHeaderField: "OpenAI-Organization")
        }
        if let projectID, !projectID.isEmpty {
            request.addValue(projectID, forHTTPHeaderField: "OpenAI-Project")
        }

        struct ContentBlock: Encodable {
            let type: String
            let text: String
        }

        struct InputMessage: Encodable {
            let role: String
            let content: [ContentBlock]

            init(role: String, text: String) {
                self.role = role
                self.content = [ContentBlock(type: "input_text", text: text)]
            }
        }

        struct Reasoning: Encodable {
            let effort: String
        }

        struct TextOptions: Encodable {
            let verbosity: String
        }

        struct Payload: Encodable {
            let model: String
            let instructions: String?
            let input: [InputMessage]
            let reasoning: Reasoning?
            let text: TextOptions?
            let max_output_tokens: Int?
            let store: Bool?
        }

        let payload = Payload(
            model: model,
            instructions: instructions,
            input: [
                InputMessage(role: "user", text: prompt)
            ],
            reasoning: reasoningEffort.map { Reasoning(effort: $0.rawValue) },
            text: textVerbosity.map { TextOptions(verbosity: $0.rawValue) },
            max_output_tokens: maxTokens,
            store: store
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GPTError.requestFailed(status: -1, message: "Invalid HTTP response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("OpenAI request failed: status=\(httpResponse.statusCode) body=\(message, privacy: .public)")
            throw GPTError.requestFailed(status: httpResponse.statusCode, message: message)
        }

        if let text = String(data: data, encoding: .utf8) {
            logger.debug("GPT-5 raw response: \(text, privacy: .public)")
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let outputText = (json["output_text"] as? [String])?.first, !outputText.isEmpty {
                    return outputText
                }
                var collected: [String] = []
                if let output = json["output"] as? [[String: Any]] {
                    for item in output {
                        guard let content = item["content"] as? [[String: Any]] else { continue }
                        for block in content {
                            if let type = block["type"] as? String, type == "output_text" {
                                if let texDict = block["text"] as? [String: Any], let value = texDict["value"] as? String {
                                    collected.append(value)
                                } else if let value = block["text"] as? String {
                                    collected.append(value)
                                }
                            } else if let value = block["text"] as? String {
                                collected.append(value)
                            }
                        }
                    }
                }
                if !collected.isEmpty {
                    if let status = json["status"] as? String, status != "completed" {
                        let reason = ((json["incomplete_details"] as? [String: Any])?["reason"] as? String) ?? "unknown"
                        logger.warning("GPT-5 response incomplete (reason: \(reason)). Returning partial output.")
                    }
                    return collected.joined(separator: "
")
                }
                if let status = json["status"] as? String, status != "completed" {
                    let reason = ((json["incomplete_details"] as? [String: Any])?["reason"] as? String) ?? "unknown"
                    logger.warning("GPT-5 response incomplete without body (reason: \(reason))")
                }
            }
        }

        logger.error("GPT-5 response missing output_text content")
        throw GPTError.decodingFailed
    }
}
