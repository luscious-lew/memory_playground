import Foundation

struct TextContactSummary: Identifiable, Hashable {
    let id: String
    let displayName: String
    let messageCount: Int
    let lastMessage: Date
    let preview: String

    var formattedLastMessage: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastMessage, relativeTo: Date())
    }
}
