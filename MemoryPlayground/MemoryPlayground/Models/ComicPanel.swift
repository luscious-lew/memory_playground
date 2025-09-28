import Foundation

struct ComicPanel: Identifiable, Codable {
    var id: UUID
    let title: String
    let caption: String
    let imagePrompt: String
    let dialogue: [String]
    var imageData: Data?

    init(id: UUID = UUID(), title: String, caption: String, imagePrompt: String, dialogue: [String] = [], imageData: Data? = nil) {
        self.id = id
        self.title = title
        self.caption = caption
        self.imagePrompt = imagePrompt
        self.dialogue = dialogue
        self.imageData = imageData
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case caption
        case imagePrompt
        case dialogue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        caption = try container.decode(String.self, forKey: .caption)
        imagePrompt = try container.decode(String.self, forKey: .imagePrompt)
        dialogue = try container.decodeIfPresent([String].self, forKey: .dialogue) ?? []
        imageData = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(caption, forKey: .caption)
        try container.encode(imagePrompt, forKey: .imagePrompt)
        if !dialogue.isEmpty {
            try container.encode(dialogue, forKey: .dialogue)
        }
    }
}
