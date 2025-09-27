import Foundation

extension ConversationItem {
    func withSpeaker(_ newSpeaker: String) -> ConversationItem {
        ConversationItem(
            id: id,
            timestamp: timestamp,
            speaker: newSpeaker,
            text: text,
            source: source,
            participantIdentifier: participantIdentifier
        )
    }
}
