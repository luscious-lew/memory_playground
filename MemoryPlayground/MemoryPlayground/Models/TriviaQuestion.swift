import Foundation

struct TriviaQuestion: Identifiable, Codable {
    var id: UUID
    let prompt: String
    let options: [String]
    let answerIndex: Int
    let funFact: String

    init(id: UUID = UUID(), prompt: String, options: [String], answerIndex: Int, funFact: String) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.answerIndex = answerIndex
        self.funFact = funFact
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case prompt
        case options
        case answerIndex
        case funFact
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        prompt = try container.decode(String.self, forKey: .prompt)
        options = try container.decode([String].self, forKey: .options)
        answerIndex = try container.decode(Int.self, forKey: .answerIndex)
        funFact = try container.decode(String.self, forKey: .funFact)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(prompt, forKey: .prompt)
        try container.encode(options, forKey: .options)
        try container.encode(answerIndex, forKey: .answerIndex)
        try container.encode(funFact, forKey: .funFact)
    }
}
