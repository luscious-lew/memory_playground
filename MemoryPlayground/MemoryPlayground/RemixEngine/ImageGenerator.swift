import Foundation
import OSLog

struct ImageGenerator {
    enum ImageError: LocalizedError {
        case missingAPIKey
        case requestFailed(status: Int, message: String)
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Provide an OpenAI API key to generate images."
            case .requestFailed(let status, let message):
                return "Image generation failed (status: \(status)): \(message)"
            case .decodingFailed:
                return "Image generation response could not be decoded."
            }
        }
    }

    private let apiKey: String?
    private let organizationID: String?
    private let projectID: String?
    private let model: String
    private let baseURL: URL
    private let session: URLSession
    private let logger = Logger(subsystem: "com.memoryplayground.app", category: "ImageGenerator")

    init(apiKey: String?,
         organizationID: String? = nil,
         projectID: String? = nil,
         model: String = "gpt-4.1-mini",
         baseURL: URL = URL(string: "https://api.openai.com/v1")!,
         session: URLSession = .shared) {
        self.apiKey = apiKey
        self.organizationID = organizationID
        self.projectID = projectID
        self.model = model
        self.baseURL = baseURL
        self.session = session
    }

    func generateImage(prompt: String, size: String = "1024x1024") async throws -> Data {
        guard let apiKey else {
            throw ImageError.missingAPIKey
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

        struct Tool: Encodable {
            let type: String
        }

        struct Payload: Encodable {
            let model: String
            let input: String
            let tools: [Tool]
            let tool_choice: Tool?
        }

        let payload = Payload(
            model: model,
            input: prompt + "\n\nImage size: \(size)",
            tools: [Tool(type: "image_generation")],
            tool_choice: Tool(type: "image_generation")
        )

        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageError.requestFailed(status: -1, message: "Invalid HTTP response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImageError.requestFailed(status: httpResponse.statusCode, message: message)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImageError.decodingFailed
        }

        if let output = json["output"] as? [[String: Any]] {
            for item in output {
                if let type = item["type"] as? String, type == "image_generation_call" {
                    if let base64 = item["result"] as? String, let imageData = Data(base64Encoded: base64) {
                        return imageData
                    }
                }
                if let content = item["content"] as? [[String: Any]] {
                    for block in content {
                        if let type = block["type"] as? String, type == "image" || type == "image_generation_call" {
                            if let base64 = block["image_base64"] as? String, let imageData = Data(base64Encoded: base64) {
                                return imageData
                            }
                            if let result = block["result"] as? String, let imageData = Data(base64Encoded: result) {
                                return imageData
                            }
                        }
                    }
                }
            }
        }

        logger.error("Image generation response missing image data: \(json, privacy: .public)")
        throw ImageError.decodingFailed
    }
}
