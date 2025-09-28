import Foundation

/// Represents a single utterance pulled from iMessage or Omi transcripts.
struct ConversationItem: Identifiable, Codable {
    enum Source: String, Codable {
        case iMessage
        case omi
        case mock
    }

    let id: UUID
    let timestamp: Date
    let speaker: String
    let text: String
    let source: Source
    let participantIdentifier: String?
    let chatGUID: String?
    let isFromMe: Bool

    init(id: UUID = UUID(),
         timestamp: Date,
         speaker: String,
         text: String,
         source: Source,
         participantIdentifier: String? = nil,
         chatGUID: String? = nil,
         isFromMe: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.speaker = speaker
        self.text = text
        self.source = source
        self.participantIdentifier = participantIdentifier
        self.chatGUID = chatGUID
        self.isFromMe = isFromMe
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case speaker
        case text
        case source
        case participantIdentifier
        case chatGUID
        case isFromMe
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        speaker = try container.decode(String.self, forKey: .speaker)
        text = try container.decode(String.self, forKey: .text)
        source = try container.decode(Source.self, forKey: .source)
        participantIdentifier = try container.decodeIfPresent(String.self, forKey: .participantIdentifier)
        chatGUID = try container.decodeIfPresent(String.self, forKey: .chatGUID)
        isFromMe = try container.decodeIfPresent(Bool.self, forKey: .isFromMe) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(speaker, forKey: .speaker)
        try container.encode(text, forKey: .text)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(participantIdentifier, forKey: .participantIdentifier)
        try container.encodeIfPresent(chatGUID, forKey: .chatGUID)
        try container.encode(isFromMe, forKey: .isFromMe)
    }
}
