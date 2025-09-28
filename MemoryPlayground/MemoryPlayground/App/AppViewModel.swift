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
    @Published var dailyNewspaper: DailyNewspaper? = nil
    @Published var roast: String = ""
    @Published var triviaQuestions: [TriviaQuestion] = []
    @Published var comicPanels: [ComicPanel] = []
    @Published var futureYou: String = ""
    @Published var loadingState: LoadingState = .idle
    @Published var isDemoModeEnabled = false
    @Published var isGeneratingRoast = false
    @Published var onboardingState: OnboardingState = []
    @Published var ingestionDiagnostics: IngestionDiagnostics = .init()

    private let ingestionManager: DataIngestionManager
    private let remixEngine: RemixEngine
    private let ingestLimit: Int
    private let demoLoader = DemoDataLoader()
    private let logger = Logger(subsystem: "com.memoryplayground.app", category: "AppViewModel")
    private let onboardingChecker = OnboardingChecker()

    init(ingestionManager: DataIngestionManager, remixEngine: RemixEngine, ingestLimit: Int) {
        self.ingestionManager = ingestionManager
        self.remixEngine = remixEngine
        self.ingestLimit = ingestLimit
    }

    convenience init() {
        let environment = ProcessInfo.processInfo.environment
        let initLogger = Logger(subsystem: "com.memoryplayground.app", category: "AppViewModel")

        let chatGUIDs = environment["IMESSAGE_CHAT_GUIDS"].map { value -> [String] in
            value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        } ?? []

        let handleFilters = environment["IMESSAGE_HANDLE_FILTERS"].map { value -> [String] in
            value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        } ?? []

        let iMessageConfig = IMessageDataSource.Configuration(
            databasePath: environment["IMESSAGE_DB_PATH"],
            limit: environment["IMESSAGE_MESSAGE_LIMIT"].flatMap { Int($0) } ?? 500,
            chatGUIDs: chatGUIDs,
            handleIdentifiers: handleFilters,
            includeGroupMessages: !(environment["IMESSAGE_INCLUDE_GROUPS"]?.lowercased() == "false")
        )

        if !FileManager.default.isReadableFile(atPath: iMessageConfig.databasePath) {
            initLogger.warning("chat.db not readable at \(iMessageConfig.databasePath, privacy: .public). Grant Full Disk Access or adjust IMESSAGE_DB_PATH.")
        }

        let iMessageSource = IMessageDataSource(configuration: iMessageConfig)
        let omiKey = environment["OMI_API_KEY"]
        if omiKey == nil { initLogger.warning("OMI_API_KEY not set. Falling back to demo transcripts.") }
        let omiClient = OmiClient(apiKey: omiKey)
        let ingestion = DataIngestionManager(iMessageDataSource: iMessageSource, omiClient: omiClient)
        let gptKey = environment["OPENAI_API_KEY"]
        if gptKey == nil { initLogger.warning("OPENAI_API_KEY not found. RemixEngine will return placeholders.") }
        let organizationID = environment["OPENAI_ORG_ID"]
        let projectID = environment["OPENAI_PROJECT_ID"]
        let gptClient = GPTClient(apiKey: gptKey, organizationID: organizationID, projectID: projectID)
        let imageGenerator = ImageGenerator(apiKey: gptKey, organizationID: organizationID, projectID: projectID)
        let remixEngine = RemixEngine(gptClient: gptClient, imageGenerator: imageGenerator)
        self.init(ingestionManager: ingestion, remixEngine: remixEngine, ingestLimit: iMessageConfig.limit)
        self.onboardingState = onboardingChecker.currentState()
    }

    func refreshOnboarding() {
        onboardingState = onboardingChecker.currentState()
    }

    func requestContactsAccess() {
        Task {
            await ContactResolver.shared.requestAccessIfNeeded()
            await MainActor.run {
                self.onboardingState = self.onboardingChecker.currentState()
            }
        }
    }

    func load() {
        onboardingState = onboardingChecker.currentState()
        let hasFullDiskAccess = onboardingState.contains(.fullDiskAccess)
        if !hasFullDiskAccess {
            logger.warning("Full Disk Access not verified. Proceeding and falling back to demo data if ingestion fails.")
        }
        guard onboardingState.contains(.apiKeysConfigured) else {
            loadingState = .failed("Add OPENAI_API_KEY and OMI_API_KEY before remixing.")
            conversations = demoLoader.load()
            isDemoModeEnabled = true
            return
        }

        loadingState = .loading
        Task {
            await ContactResolver.shared.requestAccessIfNeeded()
            onboardingState = onboardingChecker.currentState()
            let items = await ingestionManager.ingest(limit: ingestLimit)
            await MainActor.run {
                if items.isEmpty {
                    if !hasFullDiskAccess {
                        logger.warning("Ingestion returned no items; still missing Full Disk Access? Showing demo data instead.")
                    }
                    self.conversations = demoLoader.load()
                    self.isDemoModeEnabled = true
                    self.ingestionDiagnostics = .init(status: .failed("No messages ingested"), sampleMessages: [])
                    logger.info("Using demo data: \(self.conversations.count) items")
                } else {
                    self.conversations = items
                    self.isDemoModeEnabled = false
                    self.ingestionDiagnostics = IngestionDiagnostics(status: .success(count: items.count), sampleMessages: Array(items.prefix(3)))
                    logger.info("Loaded real data: \(items.count) items, first 3: \(items.prefix(3).map { $0.text.prefix(30) })")
                }
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
        logger.info("Refresh button pressed - reloading data")
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

    func regenerateNewspaper() {
        guard !conversations.isEmpty else { return }
        let snapshot = conversations
        Task {
            let updated = await remixEngine.generateDailyNewspaper(conversations: snapshot)
            await MainActor.run {
                self.dailyNewspaper = updated
            }
        }
    }

    func regenerateTrivia() {
        guard !conversations.isEmpty else { return }
        let snapshot = conversations
        Task {
            let updated = await remixEngine.generateTrivia(conversations: snapshot)
            await MainActor.run {
                self.triviaQuestions = updated
            }
        }
    }

    func regenerateComic() {
        guard !conversations.isEmpty else { return }
        let snapshot = conversations
        Task {
            let updated = await remixEngine.generateComic(conversations: snapshot)
            await MainActor.run {
                self.comicPanels = updated
            }
        }
    }

    func regenerateFutureYou() {
        guard !conversations.isEmpty else { return }
        let snapshot = conversations
        Task {
            let updated = await remixEngine.generateFutureYou(conversations: snapshot)
            await MainActor.run {
                self.futureYou = updated
            }
        }
    }

    private func generateRemixes() async {
        let items = conversations
        logger.info("Generating remixes for \(items.count) conversations")

        async let newspaperTask = remixEngine.generateDailyNewspaper(conversations: items)
        async let roastTask = remixEngine.generateRoast(conversations: items)
        async let triviaTask = remixEngine.generateTrivia(conversations: items)
        async let comicTask = remixEngine.generateComic(conversations: items)
        async let futureTask = remixEngine.generateFutureYou(conversations: items)

        let newspaper = await newspaperTask
        let roast = await roastTask
        let trivia = await triviaTask
        let comic = await comicTask
        let future = await futureTask

        await MainActor.run {
            self.dailyNewspaper = newspaper
            self.roast = roast
            self.triviaQuestions = trivia
            self.comicPanels = comic
            self.futureYou = future

            let paperHeadline = newspaper.leadHeadline ?? "n/a"
            logger.info("Remixes generated - Newspaper lead: \(paperHeadline, privacy: .public), Roast: \(roast.prefix(50))..., Trivia: \(trivia.count) questions, Comic: \(comic.count) panels, Future: \(future.prefix(50))...")
        }
    }
}

struct IngestionDiagnostics: Equatable {
    enum Status: Equatable {
        case idle
        case success(count: Int)
        case failed(String)
    }

    var status: Status
    var sampleMessages: [ConversationItem]

    init(status: Status = .idle, sampleMessages: [ConversationItem] = []) {
        self.status = status
        self.sampleMessages = sampleMessages
    }

    static func == (lhs: IngestionDiagnostics, rhs: IngestionDiagnostics) -> Bool {
        lhs.status == rhs.status && lhs.sampleMessages.map(\.id) == rhs.sampleMessages.map(\.id)
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
