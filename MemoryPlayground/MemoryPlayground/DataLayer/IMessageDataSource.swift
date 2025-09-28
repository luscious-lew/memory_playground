import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Reads the local iMessage chat.db after the user grants Full Disk Access.
actor IMessageDataSource {
    struct Configuration {
        var databasePath: String
        var limit: Int
        var chatGUIDs: [String]
        var handleIdentifiers: [String]
        var includeGroupMessages: Bool

        init(databasePath: String? = nil,
             limit: Int = 500,
             chatGUIDs: [String] = [],
             handleIdentifiers: [String] = [],
             includeGroupMessages: Bool = true) {
            // Use the current user's home directory
            let defaultPath = NSString(string: "~/Library/Messages/chat.db").expandingTildeInPath
            self.databasePath = databasePath ?? defaultPath
            self.limit = limit
            self.chatGUIDs = chatGUIDs
            self.handleIdentifiers = handleIdentifiers
            self.includeGroupMessages = includeGroupMessages
        }
    }

    private var configuration: Configuration
    private var databaseURL: URL {
        URL(fileURLWithPath: configuration.databasePath)
    }

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    func updateConfiguration(_ configuration: Configuration) {
        self.configuration = configuration
    }

    func fetchRecentMessages(limit overrideLimit: Int? = nil) async throws -> [ConversationItem] {
        guard FileManager.default.isReadableFile(atPath: databaseURL.path) else {
            throw DataSourceError.missingPermissions
        }

        let limit = overrideLimit ?? configuration.limit

        var db: OpaquePointer?
        defer { if db != nil { sqlite3_close(db) } }

        if sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            throw DataSourceError.connectionFailed(message: sqliteErrorMessage(db))
        }

        var sql = """
        SELECT
            message.guid,
            message.date,
            message.is_from_me,
            handle.id as handle,
            message.text as text_body,
            message.attributedBody as attributed_body,
            chat.guid as chatGuid
        FROM message
        LEFT JOIN handle ON message.handle_id = handle.ROWID
        LEFT JOIN chat_message_join ON message.ROWID = chat_message_join.message_id
        LEFT JOIN chat ON chat_message_join.chat_id = chat.ROWID
        WHERE (message.text IS NOT NULL OR message.attributedBody IS NOT NULL)
        """

        var conditions: [String] = []
        var bindings: [String] = []

        if !configuration.chatGUIDs.isEmpty {
            let placeholders = Array(repeating: "?", count: configuration.chatGUIDs.count).joined(separator: ",")
            conditions.append("chat.guid IN (\(placeholders))")
            bindings.append(contentsOf: configuration.chatGUIDs)
        }

        if !configuration.handleIdentifiers.isEmpty {
            let placeholders = Array(repeating: "?", count: configuration.handleIdentifiers.count).joined(separator: ",")
            conditions.append("(handle.id IN (\(placeholders)) OR message.is_from_me = 1)")
            bindings.append(contentsOf: configuration.handleIdentifiers)
        }

        if !configuration.includeGroupMessages {
            conditions.append("(chat.number_of_parts <= 2 OR chat.number_of_parts IS NULL)")
        }

        if !conditions.isEmpty {
            sql += " AND " + conditions.joined(separator: " AND ")
        }

        sql += """
        ORDER BY message.date DESC
        LIMIT ?;
        """

        var statement: OpaquePointer?
        defer { if statement != nil { sqlite3_finalize(statement) } }

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw DataSourceError.queryFailed(message: sqliteErrorMessage(db))
        }

        var bindIndex: Int32 = 1
        for value in bindings {
            sqlite3_bind_text(statement, bindIndex, (value as NSString).utf8String, -1, SQLITE_TRANSIENT)
            bindIndex += 1
        }
        sqlite3_bind_int(statement, bindIndex, Int32(limit))

        var items: [ConversationItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let guid = sqlite3_column_text(statement, 0).flatMap { String(cString: $0) } ?? UUID().uuidString
            let rawDate = sqlite3_column_int64(statement, 1)
            let isFromMe = sqlite3_column_int(statement, 2) == 1
            let rawHandle = sqlite3_column_text(statement, 3).flatMap { String(cString: $0) }

            // Try text field first, then attributed body
            var body = ""
            let textType = sqlite3_column_type(statement, 4)
            let blobType = sqlite3_column_type(statement, 5)

            if textType != SQLITE_NULL,
               let textString = sqlite3_column_text(statement, 4) {
                body = String(cString: textString)
            }

            // If text field is NULL or empty, try attributed body
            if body.isEmpty && blobType != SQLITE_NULL {
                body = decodeMessageBody(statement: statement, column: 5)
            }

            // Clean up the body text - remove any remaining metadata
            body = cleanMessageText(body)

            // Debug logging to see what's getting through
            if body.contains("NSAttributedString") || body.contains("streamtyped") || body.contains("NSMutableAttributedString") {
                print("❌ GARBAGE DETECTED: '\(body.prefix(100))'")
                continue
            }

            // Additional aggressive checks
            if body.hasPrefix("streamtyped") || body.contains("$class") || body.contains("NS.") {
                print("❌ METADATA DETECTED: '\(body.prefix(100))'")
                continue
            }

            guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            let timestamp = appleTimestampToDate(rawDate)
            let displayName = isFromMe ? "You" : (rawHandle ?? "Unknown")

            // Final debug log for messages that make it through
            print("✅ CLEAN MESSAGE: '\(body.prefix(50))...' from \(displayName)")

            let item = ConversationItem(
                id: UUID(uuidString: guid) ?? UUID(),
                timestamp: timestamp,
                speaker: displayName,
                text: body,
                source: .iMessage,
                participantIdentifier: isFromMe ? nil : rawHandle
            )
            items.append(item)
        }

        return items.sorted { $0.timestamp > $1.timestamp }
    }

    private func cleanMessageText(_ text: String) -> String {
        // If the text contains these patterns, it's likely garbage - return empty
        let garbagePatterns = [
            "NSAttributedString", "NSMutableAttributedString",
            "streamtyped", "NSString", "NSMutableString",
            "CFAttributedString", "__NSCFString", "__NSCFConstantString"
        ]

        for pattern in garbagePatterns {
            if text.contains(pattern) {
                // This is garbled metadata, not a real message
                return ""
            }
        }

        // Additional check: if it starts with streamtyped or NS, it's garbage
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("streamtyped") || trimmed.hasPrefix("NS") || trimmed.hasPrefix("__") {
            return ""
        }

        // Check for too much metadata-like content
        let metadataCount = (trimmed.components(separatedBy: "NS").count - 1) +
                           (trimmed.components(separatedBy: "CF").count - 1) +
                           (trimmed.components(separatedBy: "__").count - 1) +
                           (trimmed.components(separatedBy: "$").count - 1)

        if metadataCount > 1 {
            // This is likely garbled metadata
            return ""
        }

        // If after all checks, the message is too short or still looks like metadata, skip it
        if trimmed.count < 2 || isLikelyMetadata(trimmed) {
            return ""
        }

        return trimmed
    }

    private func isLikelyMetadata(_ text: String) -> Bool {
        // Check if text looks like metadata rather than a real message
        let lowercased = text.lowercased()

        // Check for common patterns that indicate metadata
        if lowercased.hasPrefix("ns") || lowercased.hasPrefix("cf") || lowercased.hasPrefix("__") {
            return true
        }

        // Check if it's just a class name
        if !text.contains(" ") && (text.contains("String") || text.contains("Dictionary") || text.contains("Array")) {
            return true
        }

        return false
    }

    private func decodeMessageBody(statement: OpaquePointer?, column: Int32) -> String {
        // First check if it's plain text
        if let cString = sqlite3_column_text(statement, column) {
            let text = String(cString: cString)
            // But check if it's garbage that got stored as text
            if text.contains("NSAttributedString") || text.contains("streamtyped") {
                return ""
            }
            return text
        }

        // Get the blob data
        let length = Int(sqlite3_column_bytes(statement, column))
        guard length > 0, let blobPointer = sqlite3_column_blob(statement, column) else {
            return ""
        }

        let data = Data(bytes: blobPointer, count: length)

        // Try standard NSAttributedString decoding FIRST (most common in modern iMessage)
        if let attributed = decodeAttributedBody(data) {
            // Clean the extracted text
            let cleaned = cleanMessageText(attributed)
            if !cleaned.isEmpty {
                return cleaned
            }
        }

        // If that failed, try extracting from typed stream
        if let text = extractTextFromTypedStream(data) {
            let cleaned = cleanMessageText(text)
            if !cleaned.isEmpty {
                return cleaned
            }
        }

        // Try as archived string
        if let archivedString = decodeArchivedString(data) {
            let cleaned = cleanMessageText(archivedString)
            if !cleaned.isEmpty {
                return cleaned
            }
        }

        // Don't try plain UTF-8 as it often produces garbage
        return ""
    }

    private func extractTextFromTypedStream(_ data: Data) -> String? {
        // iMessage stores attributed text in a specific binary format
        // We need to extract the actual message content from the blob

        // Check if this is a streamtyped format
        let streamtypedPrefix = "streamtyped".data(using: .ascii)!
        if data.prefix(streamtypedPrefix.count) == streamtypedPrefix {
            // Skip the streamtyped header and look for text
            return extractTextFromBinaryData(data.dropFirst(streamtypedPrefix.count))
        }

        return extractTextFromBinaryData(data)
    }

    private func extractTextFromBinaryData(_ data: Data) -> String? {
        // Strategy: Look for Unicode text patterns in the binary data
        // Messages are often stored as UTF-16 or UTF-8 strings

        // Try to find NSString patterns
        let nsStringPattern = "NSString".data(using: .ascii)!
        let nsMutableStringPattern = "NSMutableString".data(using: .ascii)!

        // Look for the actual text content after these markers
        if let range = data.range(of: nsStringPattern) ?? data.range(of: nsMutableStringPattern) {
            let afterMarker = data[range.upperBound...]

            // Try to extract text from the data following the marker
            if let text = extractReadableText(from: afterMarker) {
                return text
            }
        }

        // Fallback: Try to extract any readable text
        return extractReadableText(from: data)
    }

    private func extractReadableText(from data: Data) -> String? {
        // Look for UTF-8 encoded strings within the binary data
        // This often works when NSKeyedUnarchiver fails

        let bytes = [UInt8](data)
        var foundStrings: [String] = []

        // Try to find NULL-terminated C strings
        var currentString = Data()
        for byte in bytes {
            if byte == 0 {
                // End of C string
                if currentString.count > 3,
                   let string = String(data: currentString, encoding: .utf8),
                   !isMetadata(string) {
                    foundStrings.append(string)
                }
                currentString = Data()
            } else if byte >= 32 && byte < 127 {
                // Printable ASCII
                currentString.append(byte)
            } else {
                // Non-printable - reset
                if currentString.count > 3,
                   let string = String(data: currentString, encoding: .utf8),
                   !isMetadata(string) {
                    foundStrings.append(string)
                }
                currentString = Data()
            }
        }

        // Check final string
        if currentString.count > 3,
           let string = String(data: currentString, encoding: .utf8),
           !isMetadata(string) {
            foundStrings.append(string)
        }

        // Return the longest meaningful string
        return foundStrings
            .filter { $0.count > 3 && !isMetadata($0) }
            .max(by: { $0.count < $1.count })
    }

    private func isMetadata(_ text: String) -> Bool {
        let metadataPatterns = [
            "NSString", "NSMutableString", "NSAttributedString", "NSMutableAttributedString",
            "NSParagraphStyle", "NSFont", "NSColor", "NSData", "NSArray", "NSDictionary",
            "__NSCFString", "__NSCFConstantString", "CFString", "streamtyped",
            "$class", "$classname", "$version", "NS.string", "NS.attributes"
        ]

        for pattern in metadataPatterns {
            if text.contains(pattern) {
                return true
            }
        }

        // Check if it looks like a class name or system string
        if text.hasPrefix("NS") || text.hasPrefix("__") || text.hasPrefix("CF") {
            return true
        }

        return false
    }

    private func scoreText(_ text: String) -> Int {
        var score = 0

        // Prefer longer texts
        score += text.count

        // Prefer texts with spaces (likely real messages)
        if text.contains(" ") {
            score += 50
        }

        // Prefer texts that look like sentences
        if text.rangeOfCharacter(from: CharacterSet.letters) != nil {
            score += 30
        }

        // Penalize texts that look like metadata
        if text.contains("String") || text.contains("NS") || text.contains("CF") {
            score -= 100
        }

        return score
    }

    private func appleTimestampToDate(_ value: Int64) -> Date {
        // Apple stores iMessage dates as seconds or nanoseconds relative to 2001-01-01 00:00:00 UTC.
        let reference = Date(timeIntervalSinceReferenceDate: 0)
        let seconds: Double
        if value > 10_000_000_000 { // nanoseconds
            seconds = Double(value) / 1_000_000_000
        } else {
            seconds = Double(value)
        }
        return reference.addingTimeInterval(seconds)
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

    private func decodeAttributedBody(_ data: Data) -> String? {
        // Skip the streamtyped prefix if present
        var cleanData = data
        let streamtypedPrefix = "streamtyped".data(using: .ascii)!
        if data.starts(with: streamtypedPrefix) {
            cleanData = data.dropFirst(streamtypedPrefix.count)
        }

        // Try modern NSKeyedUnarchiver with different classes
        let classesToTry: [AnyClass] = [
            NSMutableAttributedString.self,
            NSAttributedString.self
        ]

        // Try NSMutableAttributedString first
        if let attributed = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSMutableAttributedString.self, from: cleanData) {
            let text = attributed.string
            if !text.isEmpty && !text.contains("NSAttributedString") {
                return text
            }
        }

        // Try NSAttributedString
        if let attributed = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: cleanData) {
            let text = attributed.string
            if !text.isEmpty && !text.contains("NSAttributedString") {
                return text
            }
        }

        // Try legacy unarchiving with secure coding disabled
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: cleanData)
            unarchiver.requiresSecureCoding = false
            defer { unarchiver.finishDecoding() }

            // Try different root keys
            let keysToTry = [NSKeyedArchiveRootObjectKey, "root", "NS.string", "string"]

            for key in keysToTry {
                if let attributed = unarchiver.decodeObject(forKey: key) as? NSAttributedString {
                    let text = attributed.string
                    if !text.isEmpty && !text.contains("NSAttributedString") {
                        return text
                    }
                }

                // Also try direct string
                if let string = unarchiver.decodeObject(forKey: key) as? String {
                    if !string.isEmpty && !string.contains("NSAttributedString") {
                        return string
                    }
                }
            }
        } catch {
            // Continue to fallback
        }

        return nil
    }

    private func decodeArchivedString(_ data: Data) -> String? {
        if let string = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: data) {
            return String(string)
        }

        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            defer { unarchiver.finishDecoding() }
            if let string = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? String {
                return string
            }
        } catch {
            // fall through to other decoding attempts
        }

        return nil
    }
}
