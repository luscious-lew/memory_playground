import Foundation

struct DailyNewspaper: Equatable {
    struct Story: Identifiable, Equatable {
        var id: UUID
        var headline: String
        var subheadline: String
        var body: String

        init(id: UUID = UUID(), headline: String, subheadline: String = "", body: String) {
            self.id = id
            self.headline = headline
            self.subheadline = subheadline
            self.body = body
        }
    }

    struct Quote: Equatable {
        var text: String
        var attribution: String?
    }

    struct Gossip: Equatable {
        var headline: String
        var body: String
    }

    var masthead: String
    var leadStory: Story?
    var featureStories: [Story]
    var quoteOfDay: Quote?
    var gossipColumn: Gossip?
    var rawText: String

    init(masthead: String = "The Lewis Times",
         leadStory: Story?,
         featureStories: [Story],
         quoteOfDay: Quote?,
         gossipColumn: Gossip?,
         rawText: String) {
        self.masthead = masthead
        self.leadStory = leadStory
        self.featureStories = featureStories
        self.quoteOfDay = quoteOfDay
        self.gossipColumn = gossipColumn
        self.rawText = rawText
    }

    init(rawText: String) {
        self.init(masthead: "The Lewis Times",
                  leadStory: nil,
                  featureStories: [],
                  quoteOfDay: nil,
                  gossipColumn: nil,
                  rawText: rawText)
    }

    var leadHeadline: String? {
        leadStory?.headline ?? featureStories.first?.headline
    }

    var allStories: [Story] {
        var stories: [Story] = []
        if let lead = leadStory {
            stories.append(lead)
        }
        for story in featureStories {
            if !stories.contains(where: { $0.id == story.id || $0.headline == story.headline }) {
                stories.append(story)
            }
        }
        return stories
    }
}

// MARK: - Decoding helpers

struct DailyNewspaperPayload: Codable {
    struct StoryPayload: Codable {
        var id: UUID?
        var headline: String
        var subheadline: String?
        var body: String
    }

    struct QuotePayload: Codable {
        var text: String
        var attribution: String?
    }

    struct GossipPayload: Codable {
        var headline: String
        var body: String
    }

    var masthead: String?
    var leadStory: StoryPayload
    var featureStories: [StoryPayload]
    var quoteOfDay: QuotePayload?
    var gossipColumn: GossipPayload?

    private enum CodingKeys: String, CodingKey {
        case masthead
        case leadStory
        case featureStories
        case quoteOfDay
        case gossipColumn
    }

    init(masthead: String? = nil,
         leadStory: StoryPayload,
         featureStories: [StoryPayload] = [],
         quoteOfDay: QuotePayload? = nil,
         gossipColumn: GossipPayload? = nil) {
        self.masthead = masthead
        self.leadStory = leadStory
        self.featureStories = featureStories
        self.quoteOfDay = quoteOfDay
        self.gossipColumn = gossipColumn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        masthead = try container.decodeIfPresent(String.self, forKey: .masthead)
        leadStory = try container.decode(StoryPayload.self, forKey: .leadStory)
        featureStories = try container.decodeIfPresent([StoryPayload].self, forKey: .featureStories) ?? []
        quoteOfDay = try container.decodeIfPresent(QuotePayload.self, forKey: .quoteOfDay)
        gossipColumn = try container.decodeIfPresent(GossipPayload.self, forKey: .gossipColumn)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(masthead, forKey: .masthead)
        try container.encode(leadStory, forKey: .leadStory)
        try container.encode(featureStories, forKey: .featureStories)
        try container.encodeIfPresent(quoteOfDay, forKey: .quoteOfDay)
        try container.encodeIfPresent(gossipColumn, forKey: .gossipColumn)
    }
}

extension DailyNewspaper {
    init(payload: DailyNewspaperPayload, rawText: String) {
        func convert(_ payload: DailyNewspaperPayload.StoryPayload) -> Story {
            Story(id: payload.id ?? UUID(),
                  headline: payload.headline.trimmingCharacters(in: .whitespacesAndNewlines),
                  subheadline: payload.subheadline?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                  body: payload.body.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let lead = convert(payload.leadStory)
        let others = payload.featureStories.map(convert)

        let quote: DailyNewspaper.Quote? = {
            guard let payloadQuote = payload.quoteOfDay else { return nil }
            let text = payloadQuote.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let attribution = payloadQuote.attribution?.trimmingCharacters(in: .whitespacesAndNewlines)
            return DailyNewspaper.Quote(text: text, attribution: attribution)
        }()

        let gossip: DailyNewspaper.Gossip? = {
            guard let payloadGossip = payload.gossipColumn else { return nil }
            let headline = payloadGossip.headline.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = payloadGossip.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !headline.isEmpty || !body.isEmpty else { return nil }
            return DailyNewspaper.Gossip(headline: headline.isEmpty ? "Gossip" : headline,
                                         body: body.isEmpty ? "" : body)
        }()

        self.init(masthead: payload.masthead?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "The Lewis Times",
                  leadStory: lead,
                  featureStories: others,
                  quoteOfDay: quote,
                  gossipColumn: gossip,
                  rawText: rawText)
    }

    mutating func fillMissing(from fallback: DailyNewspaper) {
        if leadStory == nil {
            leadStory = fallback.leadStory
        }

        if featureStories.isEmpty {
            featureStories = fallback.featureStories
        } else if featureStories.count < fallback.featureStories.count {
            let additional = fallback.featureStories.dropFirst(featureStories.count)
            featureStories.append(contentsOf: additional)
        }

        if quoteOfDay == nil {
            quoteOfDay = fallback.quoteOfDay
        }

        if gossipColumn == nil {
            gossipColumn = fallback.gossipColumn
        }
    }

    static func fallback(from rawText: String) -> DailyNewspaper? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let blocks = trimmed
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !blocks.isEmpty else { return nil }

        var stories: [Story] = []

        for block in blocks {
            if let story = parseStoryBlock(block) {
                stories.append(story)
            }
        }

        guard !stories.isEmpty else { return nil }

        let lead = stories.first
        let features = Array(stories.dropFirst())

        return DailyNewspaper(masthead: "The Lewis Times",
                              leadStory: lead,
                              featureStories: features,
                              quoteOfDay: nil,
                              gossipColumn: nil,
                              rawText: rawText)
    }

    private static func parseStoryBlock(_ block: String) -> Story? {
        let lines = block
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        var headline = ""
        var subheadline = ""
        var bodyLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()

            if lower.hasPrefix("headline:") {
                let value = trimmed.dropFirst("headline:".count)
                headline = value.trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            if lower.hasPrefix("subheadline:") {
                let value = trimmed.dropFirst("subheadline:".count)
                subheadline = value.trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            if headline.isEmpty {
                let stripped = trimmed.replacingOccurrences(of: #"^\d+\)\s*"#, with: "", options: .regularExpression)
                if stripped != trimmed, !stripped.isEmpty {
                    headline = stripped
                    continue
                }
            }

            bodyLines.append(trimmed)
        }

        if headline.isEmpty {
            headline = lines.first ?? ""
        }

        let body = bodyLines.joined(separator: " ")
        guard !headline.isEmpty || !body.isEmpty else { return nil }

        return Story(headline: headline, subheadline: subheadline, body: body)
    }
}
