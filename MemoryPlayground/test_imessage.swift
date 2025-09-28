#!/usr/bin/env swift

import Foundation
import SQLite3

let dbPath = NSString(string: "~/Library/Messages/chat.db").expandingTildeInPath
var db: OpaquePointer?

if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
    print("✅ Opened database successfully\n")

    let sql = """
    SELECT
        message.text,
        message.attributedBody,
        LENGTH(message.attributedBody) as blob_length,
        handle.id
    FROM message
    LEFT JOIN handle ON message.handle_id = handle.ROWID
    WHERE (message.text IS NOT NULL OR message.attributedBody IS NOT NULL)
    ORDER BY message.date DESC
    LIMIT 5
    """

    var statement: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
        print("Sample messages:\n")
        var index = 1

        while sqlite3_step(statement) == SQLITE_ROW {
            print("Message \(index):")

            // Check text field
            if let textPtr = sqlite3_column_text(statement, 0) {
                let text = String(cString: textPtr)
                print("  Text field: '\(text)'")
            } else {
                print("  Text field: NULL")
            }

            // Check attributed body
            let blobLength = sqlite3_column_int(statement, 2)
            if blobLength > 0 {
                print("  AttributedBody: \(blobLength) bytes blob")

                if let blobPtr = sqlite3_column_blob(statement, 1) {
                    let data = Data(bytes: blobPtr, count: Int(blobLength))

                    // Check for streamtyped header
                    let prefix = data.prefix(20)
                    if prefix.starts(with: "streamtyped".data(using: .ascii)!) {
                        print("  Format: streamtyped (iMessage attributed string)")
                    }

                    // Try to find readable text in the blob
                    if let str = String(data: data, encoding: .utf8) {
                        let readable = str.components(separatedBy: .controlCharacters).joined()
                        if readable.count > 10 {
                            print("  Readable fragment: '\(readable.prefix(50))...'")
                        }
                    }
                }
            } else {
                print("  AttributedBody: NULL")
            }

            print()
            index += 1
        }
        sqlite3_finalize(statement)
    }

    sqlite3_close(db)
} else {
    print("❌ Failed to open database. Grant Full Disk Access.")
}