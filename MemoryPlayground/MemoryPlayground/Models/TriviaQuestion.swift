import Foundation

struct TriviaQuestion: Identifiable, Codable {
    let id: UUID
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
}
