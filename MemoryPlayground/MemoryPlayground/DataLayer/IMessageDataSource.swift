import Foundation
import SQLite3

/// Reads the local iMessage chat.db after the user grants Full Disk Access.
actor IMessageDataSource {
    private let databaseURL: URL

    init(databasePath: String = "/Users/lewisclements/Library/Messages/chat.db") {
        self.databaseURL = URL(fileURLWithPath: databasePath)
    }

    func fetchRecentMessages(limit: Int) async throws -> [ConversationItem] {
        guard FileManager.default.isReadableFile(atPath: databaseURL.path) else {
            throw DataSourceError.missingPermissions
        }

        var db: OpaquePointer?
        defer { if db != nil { sqlite3_close(db) } }

        if sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            throw DataSourceError.connectionFailed(message: sqliteErrorMessage(db))
        }

        let sql = """
        SELECT
            message.guid,
            message.date, -- Apple epoch in nanoseconds
            handle.id as handle,
            COALESCE(message.attributedBody, message.text) as body
        FROM message
        LEFT JOIN handle ON message.handle_id = handle.ROWID
        WHERE message.text IS NOT NULL OR message.attributedBody IS NOT NULL
        ORDER BY message.date DESC
        LIMIT ?;
        """

        var statement: OpaquePointer?
        defer { if statement != nil { sqlite3_finalize(statement) } }

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw DataSourceError.queryFailed(message: sqliteErrorMessage(db))
        }

        sqlite3_bind_int(statement, 1, Int32(limit))

        var items: [ConversationItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let guid = sqlite3_column_text(statement, 0).flatMap { String(cString: $0) } ?? UUID().uuidString
            let appleEpoch = sqlite3_column_int64(statement, 1)
            let isFromMe = sqlite3_column_int(statement, 2) == 1
            let rawHandle = sqlite3_column_text(statement, 3).flatMap { String(cString: $0) }

            let bodyValue: String
            if let cString = sqlite3_column_text(statement, 4) {
                bodyValue = String(cString: cString)
            } else if let blobPointer = sqlite3_column_blob(statement, 4) {
                let length = Int(sqlite3_column_bytes(statement, 4))
                let data = Data(bytes: blobPointer, count: length)
                bodyValue = String(data: data, encoding: .utf8) ?? ""
            } else {
                bodyValue = ""
            }

            let timestamp = Date(timeIntervalSinceReferenceDate: TimeInterval(appleEpoch) / 1_000_000_000.0 + 978_307_200)
            let displayName = isFromMe ? "You" : (rawHandle ?? "Unknown")

            let item = ConversationItem(
                id: UUID(uuidString: guid) ?? UUID(),
                timestamp: timestamp,
                speaker: displayName,
                text: bodyValue,
                source: .iMessage,
                participantIdentifier: isFromMe ? nil : rawHandle
            )
            items.append(item)
        }

        return items.sorted { $0.timestamp < $1.timestamp }
    }

    private func sqliteErrorMessage(_ db: OpaquePointer?) -> String {
        if let message = sqlite3_errmsg(db) {
            return String(cString: message)
        }
        return "Unknown SQLite error"
    }

    enum DataSourceError: LocalizedError {
        case missingPermissions
        case connectionFailed(message: String)
        case queryFailed(message: String)

        var errorDescription: String? {
            switch self {
            case .missingPermissions:
                return "Grant Full Disk Access to Memory Playground to read iMessage history."
            case .connectionFailed(let message):
                return "Unable to open chat.db: \(message)"
            case .queryFailed(let message):
                return "Failed to query chat.db: \(message)"
            }
        }
    }
}
