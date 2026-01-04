//
//  ExportService.swift
//  ScapLog
//
//  データエクスポート機能
//

import Foundation
import AppKit

class ExportService {
    static let shared = ExportService()

    private init() {}

    // MARK: - Export Methods

    func exportToJSON(summaries: [Summary], includeOCR: Bool = true) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let exportData = summaries.map { summary -> [String: Any] in
            var dict: [String: Any] = [
                "id": summary.id ?? 0,
                "timestamp": ISO8601DateFormatter().string(from: summary.timestamp),
                "summary": summary.summary,
                "created_at": ISO8601DateFormatter().string(from: summary.createdAt)
            ]
            if let appName = summary.appName {
                dict["app_name"] = appName
            }
            if let windowTitle = summary.windowTitle {
                dict["window_title"] = windowTitle
            }
            if let tags = summary.tags {
                dict["tags"] = tags
            }
            if let path = summary.screenshotPath {
                dict["screenshot_path"] = path
            }
            return dict
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "[]"
    }

    func exportToCSV(summaries: [Summary]) -> String {
        var csv = "ID,Timestamp,App Name,Window Title,Summary,Tags,Screenshot Path,Created At\n"

        for summary in summaries {
            let id = summary.id ?? 0
            let timestamp = formatDate(summary.timestamp)
            let appName = escapeCSV(summary.appName ?? "")
            let windowTitle = escapeCSV(summary.windowTitle ?? "")
            let summaryText = escapeCSV(summary.summary)
            let tags = escapeCSV(summary.tags?.joined(separator: "; ") ?? "")
            let screenshotPath = escapeCSV(summary.screenshotPath ?? "")
            let createdAt = formatDate(summary.createdAt)

            csv += "\(id),\(timestamp),\(appName),\(windowTitle),\(summaryText),\(tags),\(screenshotPath),\(createdAt)\n"
        }

        return csv
    }

    func exportToMarkdown(summaries: [Summary], title: String = "Screen Summary Export") -> String {
        var md = "# \(title)\n\n"
        md += "Generated: \(formatDate(Date()))\n\n"
        md += "Total entries: \(summaries.count)\n\n"
        md += "---\n\n"

        let grouped = Dictionary(grouping: summaries) { summary in
            Calendar.current.startOfDay(for: summary.timestamp)
        }

        for (date, daySummaries) in grouped.sorted(by: { $0.key > $1.key }) {
            md += "## \(formatDateFull(date))\n\n"

            for summary in daySummaries.sorted(by: { $0.timestamp > $1.timestamp }) {
                let time = formatTime(summary.timestamp)
                let app = summary.appName ?? "Unknown"

                md += "### \(time) - \(app)\n\n"

                if let windowTitle = summary.windowTitle, !windowTitle.isEmpty {
                    md += "> \(windowTitle)\n\n"
                }

                md += "\(summary.summary)\n\n"

                if let tags = summary.tags, !tags.isEmpty {
                    md += "Tags: \(tags.map { "`\($0)`" }.joined(separator: " "))\n\n"
                }

                md += "---\n\n"
            }
        }

        return md
    }

    func exportToText(summaries: [Summary]) -> String {
        var text = "Screen Summary Export\n"
        text += "Generated: \(formatDate(Date()))\n"
        text += "Total entries: \(summaries.count)\n"
        text += String(repeating: "=", count: 50) + "\n\n"

        for summary in summaries {
            let datetime = formatDateTime(summary.timestamp)
            let app = summary.appName ?? "Unknown"

            text += "[\(datetime)] \(app)\n"
            if let windowTitle = summary.windowTitle, !windowTitle.isEmpty {
                text += "Window: \(windowTitle)\n"
            }
            text += "\(summary.summary)\n"
            text += String(repeating: "-", count: 50) + "\n\n"
        }

        return text
    }

    // MARK: - File Export

    /// Save content to file with user-selected location
    /// - Throws: Error if file write fails
    /// - Note: Does not throw if user cancels the save dialog
    func saveToFile(content: String, format: ExportFormat) throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "screen_summary_\(formatDateCompact(Date())).\(format.fileExtension)"
        panel.message = NSLocalizedString("settings.export.save_dialog.message", comment: "")

        guard panel.runModal() == .OK, let url = panel.url else {
            // User cancelled - not an error
            return
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            print("[Export] Failed to save file: \(error)")
            throw error
        }
    }

    // MARK: - Helpers

    private func escapeCSV(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\"", with: "\"\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return "\"\(escaped)\""
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func formatDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatDateCompact(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
}

// MARK: - ExportFormat Extension

extension ExportFormat {
    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .markdown: return "md"
        case .text: return "txt"
        }
    }

    var contentType: UTType {
        switch self {
        case .json: return .json
        case .csv: return .commaSeparatedText
        case .markdown: return .plainText
        case .text: return .plainText
        }
    }
}

import UniformTypeIdentifiers
