//
//  DatabaseService.swift
//  ScapLog
//
//  SQLite3を使用（macOS標準、外部依存なし）
//

import Foundation
import SQLite3

class DatabaseService {
    static let shared = DatabaseService()

    private var db: OpaquePointer?
    private let dbPath: String
    private let dbQueue = DispatchQueue(label: "com.screensummary.database", qos: .userInitiated)

    private init() {
        let basePath = AppSettings.databasePath.path
        self.dbPath = basePath.replacingOccurrences(of: ".duckdb", with: ".sqlite")

        do {
            try openDatabase()
            try createTable()
        } catch {
            print("[DB] Init error: \(error)")
        }
    }

    deinit {
        if db != nil {
            let result = sqlite3_close_v2(db)
            if result != SQLITE_OK {
                print("[DB] Warning: Failed to close database, error code: \(result)")
            }
        }
    }

    private func openDatabase() throws {
        let dir = AppSettings.applicationSupportDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Open with FULLMUTEX for thread safety
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(dbPath, &db, flags, nil) != SQLITE_OK {
            throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func createTable() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS summaries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            summary TEXT NOT NULL,
            screenshot_path TEXT,
            app_name TEXT,
            window_title TEXT,
            created_at TEXT NOT NULL
        )
        """

        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let error = errMsg != nil ? String(cString: errMsg!) : "Unknown"
            sqlite3_free(errMsg)
            throw DatabaseError.queryFailed(error)
        }

        // Create indexes for performance
        try createIndexes()
    }

    private func createIndexes() throws {
        let indexes = [
            "CREATE INDEX IF NOT EXISTS idx_summaries_id_desc ON summaries(id DESC)",
            "CREATE INDEX IF NOT EXISTS idx_summaries_timestamp ON summaries(timestamp DESC)"
        ]

        for sql in indexes {
            var errMsg: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
                let error = errMsg != nil ? String(cString: errMsg!) : "Unknown"
                sqlite3_free(errMsg)
                print("[DB] Index warning: \(error)")
            }
        }

        // Create FTS5 virtual table for full-text search
        try createFTS5Table()
    }

    private func createFTS5Table() throws {
        // Create FTS5 virtual table
        let ftsSQL = """
        CREATE VIRTUAL TABLE IF NOT EXISTS summaries_fts USING fts5(
            summary,
            app_name,
            window_title,
            content='summaries',
            content_rowid='id'
        )
        """

        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, ftsSQL, nil, nil, &errMsg) != SQLITE_OK {
            let error = errMsg != nil ? String(cString: errMsg!) : "Unknown"
            sqlite3_free(errMsg)
            print("[DB] FTS5 warning: \(error)")
            return
        }

        // Create triggers to keep FTS in sync
        let triggers = [
            """
            CREATE TRIGGER IF NOT EXISTS summaries_ai AFTER INSERT ON summaries BEGIN
                INSERT INTO summaries_fts(rowid, summary, app_name, window_title)
                VALUES (NEW.id, NEW.summary, NEW.app_name, NEW.window_title);
            END
            """,
            """
            CREATE TRIGGER IF NOT EXISTS summaries_ad AFTER DELETE ON summaries BEGIN
                INSERT INTO summaries_fts(summaries_fts, rowid, summary, app_name, window_title)
                VALUES('delete', OLD.id, OLD.summary, OLD.app_name, OLD.window_title);
            END
            """,
            """
            CREATE TRIGGER IF NOT EXISTS summaries_au AFTER UPDATE ON summaries BEGIN
                INSERT INTO summaries_fts(summaries_fts, rowid, summary, app_name, window_title)
                VALUES('delete', OLD.id, OLD.summary, OLD.app_name, OLD.window_title);
                INSERT INTO summaries_fts(rowid, summary, app_name, window_title)
                VALUES (NEW.id, NEW.summary, NEW.app_name, NEW.window_title);
            END
            """
        ]

        for sql in triggers {
            var triggerErr: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &triggerErr) != SQLITE_OK {
                let error = triggerErr != nil ? String(cString: triggerErr!) : "Unknown"
                sqlite3_free(triggerErr)
                print("[DB] Trigger warning: \(error)")
            }
        }

        // Rebuild FTS index from existing data
        try rebuildFTSIndex()
    }

    private func rebuildFTSIndex() throws {
        let rebuildSQL = """
        INSERT OR REPLACE INTO summaries_fts(summaries_fts) VALUES('rebuild')
        """
        var errMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, rebuildSQL, nil, nil, &errMsg)
        if result != SQLITE_OK {
            let message = errMsg.map { String(cString: $0) } ?? "Unknown FTS rebuild error"
            sqlite3_free(errMsg)
            throw DatabaseError.queryFailed("FTS rebuild failed: \(message)")
        }
        if errMsg != nil { sqlite3_free(errMsg) }
    }

    /// Async version of saveSummary - thread safe
    func saveSummaryAsync(_ summary: Summary) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            dbQueue.async {
                do {
                    try self.saveSummary(summary)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func saveSummary(_ summary: Summary) throws {
        let sql = "INSERT INTO summaries (timestamp, summary, screenshot_path, app_name, window_title, created_at) VALUES (?, ?, ?, ?, ?, ?)"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        let fmt = ISO8601DateFormatter()
        let ts = fmt.string(from: summary.timestamp)
        let ca = fmt.string(from: summary.createdAt)

        try bindText(stmt, 1, ts)
        try bindText(stmt, 2, summary.summary)
        try bindText(stmt, 3, summary.screenshotPath ?? "")
        try bindText(stmt, 4, summary.appName ?? "")
        try bindText(stmt, 5, summary.windowTitle ?? "")
        try bindText(stmt, 6, ca)

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        print("[DB] Saved summary: \(summary.summary.prefix(50))...")
    }

    private func bindText(_ stmt: OpaquePointer?, _ index: Int32, _ value: String) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let result = value.withCString { cString in
            sqlite3_bind_text(stmt, index, cString, -1, transient)
        }
        if result != SQLITE_OK {
            throw DatabaseError.bindingFailed("Failed to bind text at index \(index), error code: \(result)")
        }
    }

    /// Async version - runs on database queue
    func fetchRecentSummariesAsync(limit: Int = 50, offset: Int = 0) async throws -> [Summary] {
        try await withCheckedThrowingContinuation { continuation in
            dbQueue.async {
                do {
                    let results = try self.fetchRecentSummaries(limit: limit, offset: offset)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchRecentSummaries(limit: Int = 50, offset: Int = 0) throws -> [Summary] {
        // Order by id DESC since timestamps might be empty due to earlier bugs
        let sql = "SELECT id, timestamp, summary, screenshot_path, app_name, window_title, created_at FROM summaries WHERE length(summary) > 0 ORDER BY id DESC LIMIT ? OFFSET ?"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int(stmt, 1, Int32(limit))
        sqlite3_bind_int(stmt, 2, Int32(offset))

        var results: [Summary] = []
        let fmt = ISO8601DateFormatter()

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)

            // Safely handle potentially NULL columns
            let tsStr = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            let sumText = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            let ssPath = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let appNm = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let winTtl = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let caStr = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""

            // Skip if summary is empty
            guard !sumText.isEmpty else { continue }

            results.append(Summary(
                id: id,
                timestamp: fmt.date(from: tsStr) ?? Date(),
                summary: sumText,
                screenshotPath: ssPath?.isEmpty == true ? nil : ssPath,
                appName: appNm?.isEmpty == true ? nil : appNm,
                windowTitle: winTtl?.isEmpty == true ? nil : winTtl,
                createdAt: fmt.date(from: caStr) ?? Date()
            ))
        }
        return results
    }

    /// Fetch all summaries from today
    func fetchTodaySummaries() throws -> [Summary] {
        let fmt = ISO8601DateFormatter()
        let todayStart = Calendar.current.startOfDay(for: Date())
        let todayStr = fmt.string(from: todayStart)

        let sql = """
        SELECT id, timestamp, summary, screenshot_path, app_name, window_title, created_at
        FROM summaries
        WHERE created_at >= ? AND length(summary) > 0
        ORDER BY id DESC
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        try bindText(stmt, 1, todayStr)

        var results: [Summary] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let tsStr = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            let sumText = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            let ssPath = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let appNm = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let winTtl = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let caStr = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""

            guard !sumText.isEmpty else { continue }

            results.append(Summary(
                id: id,
                timestamp: fmt.date(from: tsStr) ?? Date(),
                summary: sumText,
                screenshotPath: ssPath?.isEmpty == true ? nil : ssPath,
                appName: appNm?.isEmpty == true ? nil : appNm,
                windowTitle: winTtl?.isEmpty == true ? nil : winTtl,
                createdAt: fmt.date(from: caStr) ?? Date()
            ))
        }
        return results
    }

    /// Async version of fetchTodaySummaries
    func fetchTodaySummariesAsync() async throws -> [Summary] {
        try await withCheckedThrowingContinuation { continuation in
            dbQueue.async {
                do {
                    let results = try self.fetchTodaySummaries()
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Full-text search using FTS5
    func searchSummaries(query: String, limit: Int = 50) throws -> [Summary] {
        // Escape special FTS5 characters and create search query
        let escapedQuery = query
            .replacingOccurrences(of: "\"", with: "\"\"")
            .split(separator: " ")
            .map { "\"\($0)\"*" }
            .joined(separator: " OR ")

        let sql = """
        SELECT s.id, s.timestamp, s.summary, s.screenshot_path, s.app_name, s.window_title, s.created_at
        FROM summaries s
        JOIN summaries_fts fts ON s.id = fts.rowid
        WHERE summaries_fts MATCH ?
        ORDER BY rank
        LIMIT ?
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        try bindText(stmt, 1, escapedQuery)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var results: [Summary] = []
        let fmt = ISO8601DateFormatter()

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let tsStr = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            let sumText = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            let ssPath = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let appNm = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let winTtl = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let caStr = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""

            guard !sumText.isEmpty else { continue }

            results.append(Summary(
                id: id,
                timestamp: fmt.date(from: tsStr) ?? Date(),
                summary: sumText,
                screenshotPath: ssPath?.isEmpty == true ? nil : ssPath,
                appName: appNm?.isEmpty == true ? nil : appNm,
                windowTitle: winTtl?.isEmpty == true ? nil : winTtl,
                createdAt: fmt.date(from: caStr) ?? Date()
            ))
        }
        return results
    }

    /// Async full-text search
    func searchSummariesAsync(query: String, limit: Int = 50) async throws -> [Summary] {
        try await withCheckedThrowingContinuation { continuation in
            dbQueue.async {
                do {
                    let results = try self.searchSummaries(query: query, limit: limit)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Fetch summaries within a date range
    /// - Parameters:
    ///   - startDate: Start of the date range (inclusive)
    ///   - endDate: End of the date range (inclusive)
    /// - Returns: Array of summaries within the date range, ordered by id DESC
    /// - Throws: DatabaseError if query fails or if startDate > endDate
    /// - Note: Dates are compared as ISO8601 strings. For consistent results,
    ///         ensure dates are properly normalized (e.g., start of day / end of day)
    func fetchSummariesInRange(from startDate: Date, to endDate: Date) throws -> [Summary] {
        // Validate date range
        guard startDate <= endDate else {
            throw DatabaseError.queryFailed("開始日は終了日より前に設定してください")
        }

        let fmt = ISO8601DateFormatter()
        fmt.timeZone = TimeZone.current // Use local timezone for consistency
        let startStr = fmt.string(from: startDate)
        let endStr = fmt.string(from: endDate)

        let sql = """
        SELECT id, timestamp, summary, screenshot_path, app_name, window_title, created_at
        FROM summaries
        WHERE created_at >= ? AND created_at <= ? AND length(summary) > 0
        ORDER BY id DESC
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        try bindText(stmt, 1, startStr)
        try bindText(stmt, 2, endStr)

        var results: [Summary] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let tsStr = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            let sumText = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            let ssPath = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let appNm = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let winTtl = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            let caStr = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? ""

            // Note: SQL already filters empty summaries, but keep this as defense
            guard !sumText.isEmpty else { continue }

            results.append(Summary(
                id: id,
                timestamp: fmt.date(from: tsStr) ?? Date(),
                summary: sumText,
                screenshotPath: ssPath?.isEmpty == true ? nil : ssPath,
                appName: appNm?.isEmpty == true ? nil : appNm,
                windowTitle: winTtl?.isEmpty == true ? nil : winTtl,
                createdAt: fmt.date(from: caStr) ?? Date()
            ))
        }
        return results
    }

    /// Async version of fetchSummariesInRange
    /// - Parameters:
    ///   - startDate: Start of the date range (inclusive)
    ///   - endDate: End of the date range (inclusive)
    /// - Returns: Array of summaries within the date range
    /// - Note: This method is thread-safe and executes on the database queue.
    ///         The result is NOT guaranteed to be on MainActor - wrap UI updates with MainActor.run
    func fetchSummariesInRangeAsync(from startDate: Date, to endDate: Date) async throws -> [Summary] {
        try await withCheckedThrowingContinuation { continuation in
            dbQueue.async {
                do {
                    let results = try self.fetchSummariesInRange(from: startDate, to: endDate)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Get statistics for summaries
    func getStatistics() throws -> SummaryStatistics {
        var stats = SummaryStatistics()

        // Total count
        let countSQL = "SELECT COUNT(*) FROM summaries"
        var countStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, countSQL, -1, &countStmt, nil) == SQLITE_OK {
            if sqlite3_step(countStmt) == SQLITE_ROW {
                stats.totalCount = Int(sqlite3_column_int64(countStmt, 0))
            }
            sqlite3_finalize(countStmt)
        }

        // Today's count
        let fmt = ISO8601DateFormatter()
        let todayStart = Calendar.current.startOfDay(for: Date())
        let todayStr = fmt.string(from: todayStart)

        let todaySQL = "SELECT COUNT(*) FROM summaries WHERE created_at >= ?"
        var todayStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, todaySQL, -1, &todayStmt, nil) == SQLITE_OK {
            try bindText(todayStmt, 1, todayStr)
            if sqlite3_step(todayStmt) == SQLITE_ROW {
                stats.todayCount = Int(sqlite3_column_int64(todayStmt, 0))
            }
            sqlite3_finalize(todayStmt)
        }

        // App usage counts
        let appSQL = "SELECT app_name, COUNT(*) as cnt FROM summaries WHERE app_name IS NOT NULL AND app_name != '' GROUP BY app_name ORDER BY cnt DESC LIMIT 10"
        var appStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, appSQL, -1, &appStmt, nil) == SQLITE_OK {
            while sqlite3_step(appStmt) == SQLITE_ROW {
                if let appName = sqlite3_column_text(appStmt, 0).map({ String(cString: $0) }) {
                    let count = Int(sqlite3_column_int64(appStmt, 1))
                    stats.appUsage[appName] = count
                }
            }
            sqlite3_finalize(appStmt)
        }

        // Date range
        let rangeSQL = "SELECT MIN(created_at), MAX(created_at) FROM summaries"
        var rangeStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, rangeSQL, -1, &rangeStmt, nil) == SQLITE_OK {
            if sqlite3_step(rangeStmt) == SQLITE_ROW {
                if let minStr = sqlite3_column_text(rangeStmt, 0).map({ String(cString: $0) }) {
                    stats.firstDate = fmt.date(from: minStr)
                }
                if let maxStr = sqlite3_column_text(rangeStmt, 1).map({ String(cString: $0) }) {
                    stats.lastDate = fmt.date(from: maxStr)
                }
            }
            sqlite3_finalize(rangeStmt)
        }

        return stats
    }

    /// Delete a single summary by ID
    func deleteSummary(id: Int64) throws {
        let sql = "DELETE FROM summaries WHERE id = ?"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, id)

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        print("[DB] Deleted summary id: \(id)")
    }

    /// Async version of deleteSummary
    func deleteSummaryAsync(id: Int64) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            dbQueue.async {
                do {
                    try self.deleteSummary(id: id)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Delete summaries older than the specified date
    func deleteOldSummaries(olderThan date: Date) throws {
        let fmt = ISO8601DateFormatter()
        let dateStr = fmt.string(from: date)

        let sql = "DELETE FROM summaries WHERE created_at < ?"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        try bindText(stmt, 1, dateStr)

        if sqlite3_step(stmt) != SQLITE_DONE {
            throw DatabaseError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }

        let deletedCount = sqlite3_changes(db)
        print("[DB] Deleted \(deletedCount) old summaries")
    }

    enum DatabaseError: LocalizedError {
        case openFailed(String)
        case queryFailed(String)
        case bindingFailed(String)

        var errorDescription: String? {
            switch self {
            case .openFailed(let msg): return "DB接続: \(msg)"
            case .queryFailed(let msg): return "DB: \(msg)"
            case .bindingFailed(let msg): return "DBバインド: \(msg)"
            }
        }
    }
}
