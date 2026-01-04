//
//  HistoryView.swift
//  ScapLog
//
//  Liquid Glass Design

import SwiftUI

struct HistoryView: View {
    @State private var summaries: [Summary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedDate: Date? = nil
    @State private var viewMode: ViewMode = .timeline
    @Environment(\.dismiss) var dismiss

    enum ViewMode {
        case timeline
        case calendar
    }

    var filteredSummaries: [Summary] {
        var result = summaries

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { summary in
                summary.summary.localizedCaseInsensitiveContains(searchText) ||
                (summary.appName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Filter by date
        if let date = selectedDate {
            let calendar = Calendar.current
            result = result.filter { summary in
                calendar.isDate(summary.timestamp, inSameDayAs: date)
            }
        }

        return result
    }

    // Group summaries by date
    var groupedSummaries: [(date: Date, summaries: [Summary])] {
        let calendar = Calendar.current
        var groups: [Date: [Summary]] = [:]

        for summary in filteredSummaries {
            let dateKey = calendar.startOfDay(for: summary.timestamp)
            if groups[dateKey] == nil {
                groups[dateKey] = []
            }
            groups[dateKey]?.append(summary)
        }

        return groups.map { (date: $0.key, summaries: $0.value) }
            .sorted { $0.date > $1.date }
    }

    // Get dates that have summaries for calendar
    var datesWithSummaries: Set<Date> {
        let calendar = Calendar.current
        return Set(summaries.map { calendar.startOfDay(for: $0.timestamp) })
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar - Mini calendar with liquid glass effect
            VStack(spacing: 0) {
                CalendarSidebar(
                    selectedDate: $selectedDate,
                    datesWithSummaries: datesWithSummaries
                )
            }
            .frame(width: 220)
            .liquidGlassSidebar()

            Divider()
                .opacity(0.3)

            // Main content
            VStack(spacing: 0) {
                // Header with liquid glass effect
                HStack {
                    Text("履歴")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    // View mode toggle
                    Picker("", selection: $viewMode) {
                        Image(systemName: "list.bullet").tag(ViewMode.timeline)
                        Image(systemName: "calendar").tag(ViewMode.calendar)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)

                    Button("再読込") {
                        loadSummaries()
                    }
                    .buttonStyle(LiquidGlassButtonStyle())

                    Button("閉じる") {
                        NSApp.keyWindow?.close()
                    }
                    .buttonStyle(LiquidGlassButtonStyle())
                }
                .padding()
                .liquidGlassHeader()

                // Search & Filter bar
                HStack(spacing: 12) {
                    // Search with liquid glass effect
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("検索...", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .liquidGlassSearchField()

                    if selectedDate != nil {
                        Button("日付クリア") {
                            selectedDate = nil
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                        .controlSize(.small)
                    }

                    Spacer()

                    // Export buttons
                    Menu {
                        Button("全てコピー (テキスト)") {
                            copyAllAsText()
                        }
                        Button("今日をコピー") {
                            copyTodayAsText()
                        }
                        Button("選択範囲をコピー (Markdown)") {
                            copyFilteredAsMarkdown()
                        }
                        Divider()
                        Button("AI用にエクスポート") {
                            exportForAI()
                        }
                    } label: {
                        Label("エクスポート", systemImage: "square.and.arrow.up")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                    .menuStyle(.borderlessButton)
                    .liquidGlassCard(cornerRadius: LiquidGlass.radiusSmall)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)

                Divider().opacity(0.3)

                // Stats bar
                if !filteredSummaries.isEmpty {
                    HStack {
                        Text("\(filteredSummaries.count)件")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        if let date = selectedDate {
                            Text("•")
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(formatDateFull(date))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.accentColor, .accentColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }

                        Spacer()

                        if filteredSummaries.count != summaries.count {
                            Text("(全\(summaries.count)件中)")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .liquidGlassSectionHeader()
                }

                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .red.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text(error)
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .liquidGlassAlert(color: .red)
                    Spacer()
                } else if filteredSummaries.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: searchText.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.secondary.opacity(0.6), .secondary.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text(searchText.isEmpty ? "まだ履歴がありません" : "検索結果がありません")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .liquidGlassCard()
                    Spacer()
                } else {
                    // Timeline view with date headers
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(groupedSummaries, id: \.date) { group in
                                Section {
                                    ForEach(group.summaries) { summary in
                                        TimelineSummaryRow(summary: summary, onDelete: {
                                            deleteSummary(summary)
                                        })
                                            .padding(.horizontal)
                                            .padding(.vertical, 4)
                                    }
                                } header: {
                                    DateHeaderView(date: group.date, count: group.summaries.count)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .frame(width: 900, height: 650)
        .background {
            ZStack {
                LiquidGlassBackground()
                LiquidGlassVisualEffect(material: .hudWindow)
            }
        }
        .onAppear {
            loadSummaries()
        }
    }

    private func formatDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func loadSummaries() {
        isLoading = true
        do {
            summaries = try DatabaseService.shared.fetchRecentSummaries(limit: 500)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func copyAllAsText() {
        let text = summaries.map { formatSummaryAsText($0) }.joined(separator: "\n\n---\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyTodayAsText() {
        Task {
            do {
                let allToday = try await DatabaseService.shared.fetchTodaySummariesAsync()
                await MainActor.run {
                    let text = allToday.map { formatSummaryAsText($0) }.joined(separator: "\n\n---\n\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            } catch {
                print("[HistoryView] Failed to fetch today's summaries: \(error)")
            }
        }
    }

    private func copyFilteredAsMarkdown() {
        let text = filteredSummaries.map { formatSummaryAsMarkdown($0) }.joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func exportForAI() {
        let header = """
        # 画面キャプチャ履歴サマリ

        以下は画面キャプチャから生成されたサマリの一覧です。
        これらを分析して、ユーザーの作業内容を要約してください。

        ---

        """

        let content = filteredSummaries.map { summary in
            """
            ## \(formatDateTime(summary.timestamp))\(summary.appName.map { " - \($0)" } ?? "")

            \(summary.summary)
            """
        }.joined(separator: "\n\n")

        let fullText = header + content

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullText, forType: .string)
    }

    private func formatSummaryAsText(_ summary: Summary) -> String {
        let date = formatDateTime(summary.timestamp)
        let app = summary.appName ?? ""
        return "[\(date)] \(app)\n\(summary.summary)"
    }

    private func formatSummaryAsMarkdown(_ summary: Summary) -> String {
        let date = formatDateTime(summary.timestamp)
        let app = summary.appName.map { " (\($0))" } ?? ""
        return "### \(date)\(app)\n\n\(summary.summary)"
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func deleteSummary(_ summary: Summary) {
        guard let summaryId = summary.id else {
            print("[HistoryView] Cannot delete summary without ID")
            return
        }

        Task {
            do {
                // Delete from database
                try await DatabaseService.shared.deleteSummaryAsync(id: summaryId)

                // Delete screenshot file if exists
                if let path = summary.screenshotPath {
                    let fileManager = FileManager.default
                    if fileManager.fileExists(atPath: path) {
                        try? fileManager.removeItem(atPath: path)
                        print("[HistoryView] Deleted screenshot: \(path)")
                    }
                }

                // Remove from local array
                await MainActor.run {
                    summaries.removeAll { $0.id == summary.id }
                }

                print("[HistoryView] Deleted summary ID: \(summaryId)")
            } catch {
                print("[HistoryView] Failed to delete summary: \(error)")
            }
        }
    }
}

// カレンダーサイドバー with Liquid Glass
struct CalendarSidebar: View {
    @Binding var selectedDate: Date?
    let datesWithSummaries: Set<Date>
    @State private var displayedMonth: Date = Date()
    @State private var cachedDays: [Date?] = []
    @State private var cachedMonthKey: String = ""

    private let calendar = Calendar.current
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    moveMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(LiquidGlassIconButtonStyle(size: 28))

                Spacer()

                Text(monthYearString(displayedMonth))
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    moveMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(LiquidGlassIconButtonStyle(size: 28))
            }
            .padding(.horizontal)
            .padding(.top, 14)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)

            // Calendar grid (cached)
            let days = getCachedDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let date = day {
                        LiquidCalendarDayView(
                            date: date,
                            isSelected: isSameDay(date, selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasSummaries: datesWithSummaries.contains(calendar.startOfDay(for: date)),
                            onTap: {
                                withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                                    if isSameDay(date, selectedDate) {
                                        selectedDate = nil
                                    } else {
                                        selectedDate = date
                                    }
                                }
                            }
                        )
                    } else {
                        Text("")
                            .frame(height: 28)
                    }
                }
            }
            .padding(.horizontal, 4)

            Divider()
                .opacity(0.2)
                .padding(.top, 8)

            // Quick filters with Liquid Glass
            VStack(alignment: .leading, spacing: 8) {
                Text("クイックフィルタ")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                LiquidQuickFilterButton(
                    icon: "clock",
                    title: "今日",
                    isSelected: calendar.isDateInToday(selectedDate ?? Date.distantPast)
                ) {
                    withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                        selectedDate = Date()
                    }
                }

                LiquidQuickFilterButton(
                    icon: "arrow.counterclockwise",
                    title: "昨日",
                    isSelected: calendar.isDateInYesterday(selectedDate ?? Date.distantPast)
                ) {
                    withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                        selectedDate = calendar.date(byAdding: .day, value: -1, to: Date())
                    }
                }

                LiquidQuickFilterButton(
                    icon: "list.bullet",
                    title: "すべて表示",
                    isSelected: selectedDate == nil
                ) {
                    withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                        selectedDate = nil
                    }
                }
            }

            Spacer()
        }
    }

    private func moveMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                displayedMonth = newMonth
            }
        }
    }

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func getCachedDays() -> [Date?] {
        let key = monthYearString(displayedMonth)
        if cachedMonthKey == key && !cachedDays.isEmpty {
            return cachedDays
        }
        // Recalculate and cache
        let days = computeDaysInMonth(displayedMonth)
        DispatchQueue.main.async {
            cachedMonthKey = key
            cachedDays = days
        }
        return days
    }

    private func computeDaysInMonth(_ date: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }

    private func isSameDay(_ date1: Date, _ date2: Date?) -> Bool {
        guard let date2 = date2 else { return false }
        return calendar.isDate(date1, inSameDayAs: date2)
    }
}

// Quick filter button with Liquid Glass
struct LiquidQuickFilterButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(
                        isSelected ?
                        AnyShapeStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        ) : AnyShapeStyle(Color.secondary)
                    )
                Text(title)
                    .fontWeight(isSelected ? .medium : .regular)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                    .fill(
                        isSelected ? Color.accentColor.opacity(0.15) :
                        (isHovered ? Color.white.opacity(0.08) : Color.clear)
                    )
                    .overlay {
                        if isSelected || isHovered {
                            RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                                .strokeBorder(
                                    isSelected ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.1),
                                    lineWidth: 0.5
                                )
                        }
                    }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Calendar day cell with Liquid Glass
struct LiquidCalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasSummaries: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(isToday ? .bold : .regular)

                if hasSummaries {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 4)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 28)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                    .fill(
                        isSelected ? Color.accentColor :
                        (isToday ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                        }
                    }
            }
            .foregroundColor(isSelected ? .white : (isToday ? .accentColor : .primary))
        }
        .buttonStyle(.plain)
    }
}

// Legacy compatibility
typealias CalendarDayView = LiquidCalendarDayView

// Date section header with Liquid Glass effect
struct DateHeaderView: View {
    let date: Date
    let count: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(formatDateHeader(date))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(relativeDateString(date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(count)件")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .liquidGlassBadge(color: .accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .liquidGlassSectionHeader()
    }

    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func relativeDateString(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今日"
        } else if calendar.isDateInYesterday(date) {
            return "昨日"
        } else {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
            return "\(days)日前"
        }
    }
}

// Timeline card background - extracted for type checker
struct TimelineCardBackground: View {
    let isSelected: Bool
    var opacity: Double = 1.0

    var body: some View {
        ZStack {
            if opacity > 0.3 {
                RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                    .fill(Color.white.opacity(0.06))
                    .opacity(opacity)
            }

            if isSelected {
                RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                    .fill(Color.accentColor.opacity(0.15 * opacity))
            } else if opacity > 0.3 {
                RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1 * opacity), Color.white.opacity(0.05 * opacity)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            if isSelected {
                RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                    .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1.5)
            } else {
                RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25 * opacity), Color.white.opacity(0.1 * opacity)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        }
    }
}

// Timeline summary row with Liquid Glass card
struct TimelineSummaryRow: View {
    let summary: Summary
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @State private var isExpanded = false
    @State private var isHovered = false
    @State private var showDeleteConfirmation = false
    private let settings = AppSettings.shared

    private var cardShadowColor: Color {
        let shadowOpacity = settings.windowOpacity > 0.3 ? 0.08 : 0.02
        return isSelected ? Color.accentColor.opacity(0.2 * settings.windowOpacity) : Color.black.opacity(shadowOpacity)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Selection checkbox (when in selection mode)
            if isSelectionMode {
                Button {
                    onSelect?()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(
                            isSelected ?
                            AnyShapeStyle(
                                LinearGradient(
                                    colors: [.accentColor, .accentColor.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            ) : AnyShapeStyle(Color.secondary)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            // Timeline indicator
            VStack(spacing: 4) {
                Text(formatTime(summary.timestamp))
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 10, height: 10)

                    Circle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: 18, height: 18)
                        .blur(radius: 4)
                }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.3), .secondary.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2)
            }
            .frame(width: 50)

            // Content card with Liquid Glass style
            VStack(alignment: .leading, spacing: 10) {
                // Tappable header area for expand/collapse
                VStack(alignment: .leading, spacing: 10) {
                    // App name with icon if available
                    HStack {
                        if let appName = summary.appName {
                            HStack(spacing: 6) {
                                AppIconView(appName: appName, size: 16)
                                Text(appName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Expand indicator
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.6))
                    }

                    // Summary text
                    Text(summary.summary)
                        .font(.system(.body))
                        .lineLimit(isExpanded ? nil : 3)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSelectionMode {
                        onSelect?()
                    } else {
                        withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                            isExpanded.toggle()
                        }
                    }
                }

                // Action buttons with Liquid Glass style
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Label(isExpanded ? "折りたたむ" : "全文表示",
                              systemImage: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(LiquidGlassButtonStyle())
                    .controlSize(.mini)

                    if let path = summary.screenshotPath {
                        Button {
                            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                        } label: {
                            Label("画像", systemImage: "photo")
                                .font(.caption)
                        }
                        .buttonStyle(LiquidGlassButtonStyle())
                        .controlSize(.mini)
                    }

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(summary.summary, forType: .string)
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(LiquidGlassButtonStyle())
                    .controlSize(.mini)

                    Spacer()
                }
            }
            .padding(14)
            .background {
                TimelineCardBackground(isSelected: isSelected, opacity: settings.windowOpacity)
            }
            .clipShape(RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall))
            .shadow(color: cardShadowColor, radius: settings.windowOpacity > 0.3 ? (isHovered ? 10 : 6) : 2, x: 0, y: settings.windowOpacity > 0.3 ? (isHovered ? 5 : 3) : 1)
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping), value: isHovered)
            .animation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping), value: isSelected)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(summary.summary, forType: .string)
            } label: {
                Label("コピー", systemImage: "doc.on.doc")
            }

            if let path = summary.screenshotPath {
                Button {
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                } label: {
                    Label("スクリーンショットを開く", systemImage: "photo")
                }
            }

            Divider()

            if onDelete != nil {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("削除", systemImage: "trash")
                }
            }
        }
        .alert("履歴を削除", isPresented: $showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("この履歴を削除しますか？スクリーンショットも削除されます。")
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - App Icon View

struct AppIconView: View {
    let appName: String
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let icon = getAppIcon(for: appName) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func getAppIcon(for appName: String) -> NSImage? {
        let workspace = NSWorkspace.shared

        // Try to find running app first
        if let runningApp = workspace.runningApplications.first(where: { $0.localizedName == appName }) {
            return runningApp.icon
        }

        // Search in Applications folder
        let appPaths = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            "/Applications/Utilities/\(appName).app",
            "/System/Applications/Utilities/\(appName).app"
        ]

        for path in appPaths {
            if FileManager.default.fileExists(atPath: path) {
                return workspace.icon(forFile: path)
            }
        }

        // Try to find by searching Applications
        let fileManager = FileManager.default
        if let apps = try? fileManager.contentsOfDirectory(atPath: "/Applications") {
            for app in apps where app.hasSuffix(".app") {
                let appPath = "/Applications/\(app)"
                if let bundle = Bundle(path: appPath),
                   let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
                   name == appName {
                    return workspace.icon(forFile: appPath)
                }
            }
        }

        return nil
    }
}

#Preview {
    HistoryView()
}
