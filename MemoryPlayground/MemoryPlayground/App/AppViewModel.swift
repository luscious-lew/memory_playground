import Foundation
import os
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

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
    @Published var futureYouPortrait: Data? = nil
    @Published var loadingState: LoadingState = .idle
    @Published var isDemoModeEnabled = false
    @Published var isGeneratingRoast = false
    @Published var onboardingState: OnboardingState = []
    @Published var ingestionDiagnostics: IngestionDiagnostics = .init()
    @Published var textContactSummaries: [TextContactSummary] = []
    @Published var voiceConversations: [VoiceConversationSummary] = []
    @Published var isLoadingVoiceConversations = false
    @Published var voiceConversationsError: String?

    private let ingestionManager: DataIngestionManager
    private let remixEngine: RemixEngine
    private let ingestLimit: Int
    private let demoLoader = DemoDataLoader()
    private let logger = Logger(subsystem: "com.memoryplayground.app", category: "AppViewModel")
    private let onboardingChecker = OnboardingChecker()
    private let voiceService: VoiceConversationService?
    private var voiceDetailCache: [UUID: VoiceConversationDetail] = [:]

    private static func loadImage(named name: String) -> Data? {
#if canImport(AppKit)
        guard let image = NSImage(named: name),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return data
#elseif canImport(UIKit)
        return UIImage(named: name)?.pngData()
#else
        return nil
#endif
    }

    init(ingestionManager: DataIngestionManager, remixEngine: RemixEngine, ingestLimit: Int, voiceService: VoiceConversationService? = nil) {
        self.ingestionManager = ingestionManager
        self.remixEngine = remixEngine
        self.ingestLimit = ingestLimit
        self.voiceService = voiceService
        self.futureYouPortrait = Self.loadImage(named: "future_you_portrait")
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
        let supabaseKey = environment["SUPABASE_SERVICE_KEY"] ?? environment["SUPABASE_ANON_KEY"]
        let voiceService = supabaseKey.map { VoiceConversationService(apiKey: $0) }
        if supabaseKey == nil {
            initLogger.info("SUPABASE_SERVICE_KEY not provided; voice conversations will be disabled.")
        }
        self.init(ingestionManager: ingestion, remixEngine: remixEngine, ingestLimit: iMessageConfig.limit, voiceService: voiceService)
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
                self.rebuildTextSummaries()
            }

            if conversations.isEmpty {
                loadingState = .failed("No conversation history available. Add mock data or check permissions.")
                if voiceService != nil {
                    await loadVoiceConversations()
                }
                return
            }

            await generateRemixes()
            loadingState = .loaded

            if voiceService != nil {
                await loadVoiceConversations()
            }
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
            self.rebuildTextSummaries()

            let paperHeadline = newspaper.leadHeadline ?? "n/a"
            logger.info("Remixes generated - Newspaper lead: \(paperHeadline, privacy: .public), Roast: \(roast.prefix(50))..., Trivia: \(trivia.count) questions, Comic: \(comic.count) panels, Future: \(future.prefix(50))...")
        }
    }

    func messages(for contactID: String) -> [ConversationItem] {
        conversations.filter { contactIdentifier(for: $0) == contactID }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func contactSummary(for contactID: String) -> TextContactSummary? {
        textContactSummaries.first { $0.id == contactID }
    }

    func voiceConversationDetail(for id: UUID) async -> VoiceConversationDetail? {
        if let cached = voiceDetailCache[id] {
            return cached
        }
        guard let voiceService else { return nil }
        do {
            async let conversation = voiceService.fetchConversationWithStats(id: id)
            async let segments = voiceService.fetchSegments(for: id)
            async let plugins = voiceService.fetchPluginContent(for: id)
            let detail = try await VoiceConversationDetail(conversation: conversation, segments: segments, pluginContent: plugins)
            voiceDetailCache[id] = detail
            return detail
        } catch {
            logger.error("Failed to load voice conversation detail: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func loadVoiceConversations() async {
        guard let voiceService else { return }
        if isLoadingVoiceConversations { return }
        isLoadingVoiceConversations = true
        voiceConversationsError = nil
        do {
            let conversations = try await voiceService.fetchLatestConversations()
            voiceConversations = conversations
        } catch {
            voiceConversationsError = error.localizedDescription
            logger.error("Failed to load voice conversations: \(error.localizedDescription, privacy: .public)")
        }
        isLoadingVoiceConversations = false
    }

    private func rebuildTextSummaries() {
        let grouped = Dictionary(grouping: conversations) { contactIdentifier(for: $0) }
            .filter { !$0.key.isEmpty && $0.key != "self" }

        let summaries = grouped.compactMap { key, items -> TextContactSummary? in
            guard let last = items.max(by: { $0.timestamp < $1.timestamp }) else { return nil }
            let sorted = items.sorted { $0.timestamp > $1.timestamp }
            let preview = sorted.first?.text ?? ""
            let displayName: String
            if let other = sorted.first(where: { !$0.isFromMe })?.speaker, other != "You" {
                displayName = other
            } else if let any = sorted.first?.speaker, any != "You" {
                displayName = any
            } else {
                displayName = "You"
            }
            return TextContactSummary(
                id: key,
                displayName: displayName,
                messageCount: items.count,
                lastMessage: last.timestamp,
                preview: preview
            )
        }

        textContactSummaries = summaries.sorted { $0.lastMessage > $1.lastMessage }
    }

    private func contactIdentifier(for item: ConversationItem) -> String {
        if let chat = item.chatGUID, !chat.isEmpty {
            return chat
        }
        if let identifier = item.participantIdentifier, !identifier.isEmpty {
            return identifier
        }
        // fallback to speaker name if we truly have no identifiers
        return item.speaker
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
            ConversationItem(timestamp: now.addingTimeInterval(-3600), speaker: "Lewis", text: "We should remix the Omi logs into something fun tonight!", source: .mock, participantIdentifier: "lewis@example.com", chatGUID: "mock-chat", isFromMe: true),
            ConversationItem(timestamp: now.addingTimeInterval(-1800), speaker: "Omi", text: "Reminder: you promised to stretch before coding.", source: .mock, participantIdentifier: "omi@example.com", chatGUID: "mock-chat", isFromMe: false),
            ConversationItem(timestamp: now.addingTimeInterval(-600), speaker: "Lewis", text: "Okay fine, but only if the newspaper roasts me.", source: .mock, participantIdentifier: "lewis@example.com", chatGUID: "mock-chat", isFromMe: true)
        ]
    }
}
