import Foundation
import os

@MainActor
final class AppViewModel: ObservableObject {
    enum LoadingState {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published var conversations: [ConversationItem] = []
    @Published var dailyNewspaper: String = ""
    @Published var roast: String = ""
    @Published var triviaQuestions: [TriviaQuestion] = []
    @Published var comicPanels: [ComicPanel] = []
    @Published var futureYou: String = ""
    @Published var loadingState: LoadingState = .idle
    @Published var isDemoModeEnabled = false
    @Published var isGeneratingRoast = false

    private let ingestionManager: DataIngestionManager
    private let remixEngine: RemixEngine
    private let demoLoader = DemoDataLoader()
    private let logger = Logger(subsystem: "com.memoryplayground.app", category: "AppViewModel")

    init(ingestionManager: DataIngestionManager, remixEngine: RemixEngine) {
        self.ingestionManager = ingestionManager
        self.remixEngine = remixEngine
    }

    convenience init() {
        let environment = ProcessInfo.processInfo.environment
        let initLogger = Logger(subsystem: "com.memoryplayground.app", category: "AppViewModel")
        let iMessageSource = IMessageDataSource()
        let omiKey = environment["OMI_API_KEY"]
        if omiKey == nil { initLogger.warning("OMI_API_KEY not set. Falling back to demo transcripts.") }
        let omiClient = OmiClient(apiKey: omiKey)
        let ingestion = DataIngestionManager(iMessageDataSource: iMessageSource, omiClient: omiClient)
        let gptKey = environment["OPENAI_API_KEY"]
        if gptKey == nil { initLogger.warning("OPENAI_API_KEY not found. RemixEngine will return placeholders.") }
        let gptClient = GPTClient(apiKey: gptKey, organizationID: environment["OPENAI_ORG_ID"], projectID: environment["OPENAI_PROJECT_ID"])
        let remixEngine = RemixEngine(gptClient: gptClient)
        self.init(ingestionManager: ingestion, remixEngine: remixEngine)
    }

    func load() {
        loadingState = .loading
        Task {
            await ContactResolver.shared.requestAccessIfNeeded()
            let items = await ingestionManager.ingest(limit: 200)
            if items.isEmpty {
                conversations = demoLoader.load()
                isDemoModeEnabled = true
            } else {
                conversations = items
                isDemoModeEnabled = false
            }

            if conversations.isEmpty {
                loadingState = .failed("No conversation history available. Add mock data or check permissions.")
                return
            }

            await generateRemixes()
            loadingState = .loaded
        }
    }

    func refresh() {
        load()
    }

    func regenerateRoast() {
        guard !conversations.isEmpty else { return }
        isGeneratingRoast = true
        let snapshot = conversations
        Task {
            let updated = await remixEngine.generateRoast(conversations: snapshot)
            await MainActor.run {
                self.roast = updated
                self.isGeneratingRoast = false
            }
        }
    }

    private func generateRemixes() async {
        let items = conversations
        async let newspaperTask = remixEngine.generateDailyNewspaper(conversations: items)
        async let roastTask = remixEngine.generateRoast(conversations: items)
        async let triviaTask = remixEngine.generateTrivia(conversations: items)
        async let comicTask = remixEngine.generateComic(conversations: items)
        async let futureTask = remixEngine.generateFutureYou(conversations: items)

        dailyNewspaper = await newspaperTask
        roast = await roastTask
        triviaQuestions = await triviaTask
        comicPanels = await comicTask
        futureYou = await futureTask
    }
}

struct DemoDataLoader {
    func load() -> [ConversationItem] {
        guard let url = Bundle.main.url(forResource: "sample_conversations", withExtension: "json") else {
            return fallback()
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ConversationItem].self, from: data)
        } catch {
            return fallback()
        }
    }

    private func fallback() -> [ConversationItem] {
        let now = Date()
        return [
            ConversationItem(timestamp: now.addingTimeInterval(-3600), speaker: "Lewis", text: "We should remix the Omi logs into something fun tonight!", source: .mock),
            ConversationItem(timestamp: now.addingTimeInterval(-1800), speaker: "Omi", text: "Reminder: you promised to stretch before coding.", source: .mock),
            ConversationItem(timestamp: now.addingTimeInterval(-600), speaker: "Lewis", text: "Okay fine, but only if the newspaper roasts me.", source: .mock)
        ]
    }
}
