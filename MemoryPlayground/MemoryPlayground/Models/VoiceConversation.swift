import Foundation

struct VoiceConversationSummary: Identifiable, Hashable, Decodable {
    let id: UUID
    let createdAt: Date
    let structuredTitle: String?
    let structuredCategory: String?
    let structuredEmoji: String?
    let structuredOverview: String?
    let status: String?
    let segmentCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case structuredTitle = "structured_title"
        case structuredCategory = "structured_category"
        case structuredEmoji = "structured_emoji"
        case structuredOverview = "structured_overview"
        case status
        case segmentCount = "segment_count"
    }
}

struct VoiceConversationDetail: Decodable {
    let conversation: VoiceConversationSummary
    let segments: [VoiceSegment]
    let pluginContent: [String]
}

struct VoiceSegment: Decodable, Hashable {
    let idx: Int
    let startSec: Double?
    let endSec: Double?
    let speaker: String?
    let speakerID: Int?
    let isUser: Bool?
    let text: String

    enum CodingKeys: String, CodingKey {
        case idx
        case startSec = "start_sec"
        case endSec = "end_sec"
        case speaker
        case speakerID = "speaker_id"
        case isUser = "is_user"
        case text
    }
}
