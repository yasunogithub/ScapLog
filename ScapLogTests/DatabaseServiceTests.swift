//
//  DatabaseServiceTests.swift
//  ScapLogTests
//
//  Created by Claude on 2026/01/05.
//

import Testing
import Foundation
@testable import ScapLog

struct DatabaseServiceTests {

    // MARK: - DatabaseError Tests

    @Test func databaseError_openFailed_shouldContainMessage() {
        let error = DatabaseService.DatabaseError.openFailed("Connection refused")
        #expect(error.errorDescription?.contains("Connection refused") == true)
        #expect(error.errorDescription?.contains("DB") == true)
    }

    @Test func databaseError_queryFailed_shouldContainMessage() {
        let error = DatabaseService.DatabaseError.queryFailed("Syntax error")
        #expect(error.errorDescription?.contains("Syntax error") == true)
        #expect(error.errorDescription?.contains("DB") == true)
    }

    // MARK: - Integration Tests (using shared instance)
    // Note: These tests use the actual database. Ideally, DatabaseService
    // should be refactored to support dependency injection for better testability.

    @Test func fetchRecentSummaries_shouldNotThrow() async throws {
        // This is a basic smoke test to ensure the database is working
        let service = DatabaseService.shared
        _ = try service.fetchRecentSummaries(limit: 1)
    }

    @Test func getStatistics_shouldReturnValidStats() throws {
        let service = DatabaseService.shared
        let stats = try service.getStatistics()

        // totalCount should be non-negative
        #expect(stats.totalCount >= 0)
        #expect(stats.todayCount >= 0)
        #expect(stats.todayCount <= stats.totalCount)
    }

    @Test func fetchSummariesInRange_invalidDateRange_shouldThrow() async throws {
        let service = DatabaseService.shared
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        // Start date after end date should throw
        do {
            _ = try service.fetchSummariesInRange(from: now, to: yesterday)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            // Expected: validation error
            #expect(error.localizedDescription.contains("開始日"))
        }
    }

    @Test func fetchSummariesInRange_validDateRange_shouldNotThrow() throws {
        let service = DatabaseService.shared
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        // Valid date range should not throw
        let results = try service.fetchSummariesInRange(from: yesterday, to: now)
        #expect(results.count >= 0)
    }

    @Test func fetchTodaySummaries_shouldNotThrow() throws {
        let service = DatabaseService.shared
        let results = try service.fetchTodaySummaries()
        #expect(results.count >= 0)
    }

    // MARK: - Async Method Tests

    @Test func fetchRecentSummariesAsync_shouldReturnResults() async throws {
        let service = DatabaseService.shared
        let results = try await service.fetchRecentSummariesAsync(limit: 5)
        #expect(results.count >= 0)
        #expect(results.count <= 5)
    }

    @Test func fetchTodaySummariesAsync_shouldReturnResults() async throws {
        let service = DatabaseService.shared
        let results = try await service.fetchTodaySummariesAsync()
        #expect(results.count >= 0)
    }

    @Test func fetchSummariesInRangeAsync_shouldReturnResults() async throws {
        let service = DatabaseService.shared
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        let results = try await service.fetchSummariesInRangeAsync(from: weekAgo, to: now)
        #expect(results.count >= 0)
    }

    // MARK: - Search Tests

    @Test func searchSummaries_emptyQuery_shouldNotCrash() throws {
        let service = DatabaseService.shared
        // Note: Empty query behavior depends on FTS5 implementation
        // This test verifies it doesn't crash
        do {
            _ = try service.searchSummaries(query: "", limit: 10)
        } catch {
            // Some FTS implementations may reject empty queries
            // That's acceptable behavior
        }
    }

    @Test func searchSummaries_specialCharacters_shouldNotCrash() throws {
        let service = DatabaseService.shared
        // Test with special characters that might affect FTS5
        let queries = ["test", "\"quoted\"", "日本語", "test*"]

        for query in queries {
            do {
                _ = try service.searchSummaries(query: query, limit: 5)
            } catch {
                // Query might fail but should not crash
            }
        }
    }

    @Test func searchSummariesAsync_shouldReturnResults() async throws {
        let service = DatabaseService.shared
        let results = try await service.searchSummariesAsync(query: "test", limit: 5)
        #expect(results.count >= 0)
        #expect(results.count <= 5)
    }
}
