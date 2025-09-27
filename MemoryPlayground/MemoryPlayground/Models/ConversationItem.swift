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

    init(id: UUID = UUID(), timestamp: Date, speaker: String, text: String, source: Source, participantIdentifier: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.speaker = speaker
        self.text = text
        self.source = source
        self.participantIdentifier = participantIdentifier
    }
}
