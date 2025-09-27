import Foundation

/// Simple JSON cache to keep the most recent merged conversation history.
struct LocalCache {
    private let cacheURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(filename: String = "conversation-cache.json") {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let identifier = Bundle.main.bundleIdentifier ?? "MemoryPlayground"
        let appDirectory = supportDirectory.appendingPathComponent(identifier, isDirectory: true)
        if !FileManager.default.fileExists(atPath: appDirectory.path) {
            try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        self.cacheURL = appDirectory.appendingPathComponent(filename)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> [ConversationItem] {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: cacheURL)
            return try decoder.decode([ConversationItem].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ items: [ConversationItem]) {
        do {
            let data = try encoder.encode(items)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // This is only a cache, so we can safely ignore write errors in the demo build.
        }
    }
}
