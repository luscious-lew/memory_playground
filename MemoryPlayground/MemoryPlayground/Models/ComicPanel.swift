import Foundation

struct ComicPanel: Identifiable, Codable {
    let id: UUID
    let title: String
    let caption: String
    let illustrationPrompt: String

    init(id: UUID = UUID(), title: String, caption: String, illustrationPrompt: String) {
        self.id = id
        self.title = title
        self.caption = caption
        self.illustrationPrompt = illustrationPrompt
    }
}
