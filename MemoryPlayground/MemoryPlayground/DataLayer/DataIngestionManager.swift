import Foundation

/// Pulls recent conversations from iMessage and Omi, then merges into a single chronological stream.
actor DataIngestionManager {
    let iMessageDataSource: IMessageDataSource
    let omiClient: OmiClient
    let cache: LocalCache

    init(iMessageDataSource: IMessageDataSource = IMessageDataSource(), omiClient: OmiClient = OmiClient(apiKey: nil), cache: LocalCache = LocalCache()) {
        self.iMessageDataSource = iMessageDataSource
        self.omiClient = omiClient
        self.cache = cache
    }

    func ingest(limit: Int = 200) async -> [ConversationItem] {
        async let messages = fetchMessages(limit: limit)
        async let transcripts = fetchTranscripts(limit: limit)

        let merged = (await messages + transcripts)
            .sorted { $0.timestamp < $1.timestamp }

        let enriched = await enrichWithContacts(merged)

        if enriched.isEmpty {
            let cached = cache.load()
            if !cached.isEmpty {
                return cached
            }
        } else {
            cache.save(enriched)
        }

        return enriched
    }

    private func fetchMessages(limit: Int) async -> [ConversationItem] {
        do {
            return try await iMessageDataSource.fetchRecentMessages(limit: limit)
        } catch {
            return []
        }
    }

    private func fetchTranscripts(limit: Int) async -> [ConversationItem] {
        do {
            return try await omiClient.fetchRecentTranscripts(limit: limit)
        } catch {
            return []
        }
    }

    private func enrichWithContacts(_ items: [ConversationItem]) async -> [ConversationItem] {
        await MainActor.run {
            items.map { item in
                guard let identifier = item.participantIdentifier, !identifier.isEmpty else { return item }
                let resolved = ContactResolver.shared.displayName(for: identifier)
                guard !resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, resolved != item.speaker else { return item }
                return item.withSpeaker(resolved)
            }
        }
    }
}
