//
//  Summary.swift
//  ScapLog
//

import Foundation

struct Summary: Identifiable, Codable {
    var id: Int64?
    var timestamp: Date
    var summary: String
    var screenshotPath: String?
    var appName: String?
    var windowTitle: String?
    var createdAt: Date
    var tags: [String]?

    init(
        id: Int64? = nil,
        timestamp: Date = Date(),
        summary: String,
        screenshotPath: String? = nil,
        appName: String? = nil,
        windowTitle: String? = nil,
        createdAt: Date = Date(),
        tags: [String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.summary = summary
        self.screenshotPath = screenshotPath
        self.appName = appName
        self.windowTitle = windowTitle
        self.createdAt = createdAt
        self.tags = tags
    }
}

// MARK: - Statistics

struct SummaryStatistics {
    var totalCount: Int = 0
    var todayCount: Int = 0
    var appUsage: [String: Int] = [:]
    var firstDate: Date?
    var lastDate: Date?

    var daysSinceFirst: Int {
        guard let first = firstDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: first, to: Date()).day ?? 0
    }

    var averagePerDay: Double {
        guard daysSinceFirst > 0 else { return Double(totalCount) }
        return Double(totalCount) / Double(daysSinceFirst)
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
    case markdown = "Markdown"
    case text = "Text"
}

struct ExportOptions {
    var format: ExportFormat = .json
    var includeScreenshots: Bool = false
    var dateRange: ClosedRange<Date>?
}
