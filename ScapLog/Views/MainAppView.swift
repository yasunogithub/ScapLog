//
//  MainAppView.swift
//  ScapLog
//
//  統合メインビュー（カレンダー + 履歴 + 設定）
//

import SwiftUI
import Observation

struct MainAppView: View {
    @State private var captureManager = CaptureManager.shared
    @State private var screenCapture = ScreenCaptureService.shared
    @Bindable private var settings = AppSettings.shared

    // History state
    @State private var summaries: [Summary] = []
    @State private var searchResults: [Summary] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMoreData = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedDate: Date? = nil
    @State private var searchTask: Task<Void, Never>?

    // Selection state
    @State private var selectedIds: Set<Int64> = []
    @State private var isSelectionMode = false
    @State private var showDeleteConfirmation = false

    // App filter
    @State private var selectedAppFilter: String? = nil

    // Pagination
    private let pageSize = 50

    // Statistics sheet
    @State private var showingStatistics = false

    // Copy feedback
    @State private var showCopyFeedback = false
    @State private var copyFeedbackMessage = ""

    // Cached computed values (updated only when data changes)
    @State private var cachedDatesWithSummaries: Set<Date> = []
    @State private var cachedAvailableApps: [String] = []

    var filteredSummaries: [Summary] {
        var result = searchResults.isEmpty ? summaries : searchResults

        if let date = selectedDate {
            let calendar = Calendar.current
            result = result.filter { summary in
                calendar.isDate(summary.timestamp, inSameDayAs: date)
            }
        }

        // App filter
        if let appFilter = selectedAppFilter {
            result = result.filter { $0.appName == appFilter }
        }

        return result
    }

    /// Get unique app names for filter (cached)
    var availableApps: [String] {
        cachedAvailableApps
    }

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

    /// Dates that have summaries (cached)
    var datesWithSummaries: Set<Date> {
        cachedDatesWithSummaries
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar - Calendar
            VStack(spacing: 0) {
                CalendarSidebar(
                    selectedDate: $selectedDate,
                    datesWithSummaries: datesWithSummaries
                )
            }
            .frame(width: 220)

            Divider().opacity(0.3)

            // Main content
            VStack(spacing: 0) {
                // Header with controls
                headerView

                Divider()

                // Search bar
                searchBarView

                // Stats bar
                if !filteredSummaries.isEmpty {
                    statsBarView
                }

                // Selection bar (when in selection mode)
                if isSelectionMode {
                    selectionBarView
                }

                // Content
                contentView
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background {
            ZStack {
                LiquidGlassBackground(opacity: settings.windowOpacity)
                LiquidGlassVisualEffect(material: .hudWindow)
                    .opacity(settings.windowOpacity)
            }
        }
        .background(LiquidGlassWindowAccessor(opacity: settings.windowOpacity))
        .onAppear {
            loadSummariesAsync()
        }
        .onChange(of: summaries) { _, newValue in
            updateCachedValues(from: newValue)
        }
        .sheet(isPresented: $showingStatistics) {
            StatisticsView()
        }
        .alert("選択した履歴を削除", isPresented: $showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("削除 (\(selectedIds.count)件)", role: .destructive) {
                deleteSelectedSummaries()
            }
        } message: {
            Text("\(selectedIds.count)件の履歴とスクリーンショットを削除しますか？この操作は取り消せません。")
        }
        .overlay(alignment: .top) {
            if showCopyFeedback {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text(copyFeedbackMessage)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .liquidGlassBadge(color: .green)
                .shadow(color: .green.opacity(0.2), radius: 12, x: 0, y: 6)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .padding(.top, 80)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping), value: showCopyFeedback)
    }

    // MARK: - Export to File

    private func exportToFile(_ format: ExportFormat) {
        let data = filteredSummaries.isEmpty ? summaries : filteredSummaries
        let content: String

        switch format {
        case .json:
            content = ExportService.shared.exportToJSON(summaries: data)
        case .csv:
            content = ExportService.shared.exportToCSV(summaries: data)
        case .markdown:
            content = ExportService.shared.exportToMarkdown(summaries: data)
        case .text:
            content = ExportService.shared.exportToText(summaries: data)
        }

        try? ExportService.shared.saveToFile(content: content, format: format)
    }

    // MARK: - Search

    private func performSearch(query: String) {
        // Cancel previous search task
        searchTask?.cancel()

        guard !query.isEmpty else {
            searchResults = []
            return
        }

        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce

            guard !Task.isCancelled else { return }

            do {
                let results = try await DatabaseService.shared.searchSummariesAsync(query: query)
                await MainActor.run {
                    if !Task.isCancelled {
                        searchResults = results
                    }
                }
            } catch {
                print("[Search] Error: \(error)")
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            // Status indicator with glow
            ZStack {
                Circle()
                    .fill(captureManager.isCapturing ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 12, height: 12)

                if captureManager.isCapturing {
                    Circle()
                        .fill(Color.green.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .blur(radius: 4)
                }
            }

            Text(captureManager.isCapturing ? "キャプチャ中" : "停止中")
                .font(.headline)
                .fontWeight(.semibold)

            if captureManager.captureCount > 0 {
                Text("\(captureManager.captureCount)回")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .liquidGlassBadge(color: .accentColor)
            }

            Spacer()

            if let command = settings.selectedCommand {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text(command.name)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .liquidGlassCard(cornerRadius: LiquidGlass.radiusTiny)
            }

            Button(captureManager.isCapturing ? "停止" : "開始") {
                if captureManager.isCapturing {
                    captureManager.stopCapturing()
                } else {
                    captureManager.startCapturing()
                }
            }
            .buttonStyle(LiquidGlassButtonStyle(isProminent: true, color: captureManager.isCapturing ? .orange : .accentColor))

            Button("今すぐキャプチャ") {
                Task {
                    await captureManager.performCapture()
                    loadSummariesAsync()
                }
            }
            .buttonStyle(LiquidGlassButtonStyle())

            SettingsLink {
                Image(systemName: "gear")
            }
            .buttonStyle(LiquidGlassButtonStyle())
        }
        .padding()
        .liquidGlassHeader()
    }

    // MARK: - Search Bar View

    private var searchBarView: some View {
        HStack(spacing: 12) {
            // Selection mode toggle
            Button {
                withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedIds.removeAll()
                    }
                }
            } label: {
                Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundStyle(isSelectionMode ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(LiquidGlassIconButtonStyle())
            .help("選択モード")

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("検索...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        performSearch(query: newValue)
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .liquidGlassSearchField()

            // App filter menu
            Menu {
                Button {
                    selectedAppFilter = nil
                } label: {
                    Label("すべてのアプリ", systemImage: "square.grid.2x2")
                }
                Divider()
                ForEach(availableApps, id: \.self) { app in
                    Button {
                        selectedAppFilter = app
                    } label: {
                        HStack {
                            AppIconView(appName: app, size: 16)
                            Text(app)
                            Spacer()
                            if selectedAppFilter == app {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if let app = selectedAppFilter {
                        AppIconView(appName: app, size: 16)
                    } else {
                        Image(systemName: "app.badge")
                    }
                    Text(selectedAppFilter ?? "アプリ")
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
            .menuStyle(.borderlessButton)
            .liquidGlassCard(cornerRadius: LiquidGlass.radiusSmall)
            .frame(maxWidth: 160)

            if selectedDate != nil {
                Button("日付クリア") {
                    selectedDate = nil
                }
                .buttonStyle(LiquidGlassButtonStyle())
                .controlSize(.small)
            }

            if selectedAppFilter != nil {
                Button {
                    selectedAppFilter = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(LiquidGlassIconButtonStyle(size: 28))
                .controlSize(.small)
            }

            Spacer()

            // Quick copy today button
            Button {
                copyTodayAsText()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.doc")
                    Text("今日をコピー")
                }
            }
            .buttonStyle(LiquidGlassButtonStyle())
            .help("今日の履歴をクリップボードにコピー")

            // Export menu
            Menu {
                Section("クリップボードにコピー") {
                    Button {
                        copyTodayAsText()
                    } label: {
                        Label("今日をコピー", systemImage: "calendar")
                    }
                    Button {
                        copyFilteredAsMarkdown()
                    } label: {
                        Label("表示中をコピー (Markdown)", systemImage: "text.quote")
                    }
                    Button {
                        copyAllAsText()
                    } label: {
                        Label("全てコピー", systemImage: "doc.on.doc.fill")
                    }
                    Divider()
                    Button {
                        exportForAI()
                    } label: {
                        Label("AI用にエクスポート", systemImage: "brain")
                    }
                }
                Divider()
                Section("ファイルに保存") {
                    Button("JSON形式で保存...") {
                        exportToFile(.json)
                    }
                    Button("CSV形式で保存...") {
                        exportToFile(.csv)
                    }
                    Button("Markdown形式で保存...") {
                        exportToFile(.markdown)
                    }
                    Button("テキスト形式で保存...") {
                        exportToFile(.text)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
            }
            .menuStyle(.borderlessButton)
            .liquidGlassCard(cornerRadius: LiquidGlass.radiusSmall)

            Button {
                showingStatistics = true
            } label: {
                Image(systemName: "chart.bar")
            }
            .buttonStyle(LiquidGlassIconButtonStyle())

            Button {
                loadSummariesAsync()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(LiquidGlassIconButtonStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Stats Bar View

    private var statsBarView: some View {
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

    // MARK: - Selection Bar View

    private var selectionBarView: some View {
        HStack(spacing: 12) {
            // Select all / Deselect all
            Button {
                withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                    if selectedIds.count == filteredSummaries.count {
                        selectedIds.removeAll()
                    } else {
                        selectedIds = Set(filteredSummaries.compactMap { $0.id })
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: selectedIds.count == filteredSummaries.count ? "checkmark.square.fill" : "square")
                    Text(selectedIds.count == filteredSummaries.count ? "選択解除" : "全選択")
                }
                .font(.caption)
            }
            .buttonStyle(LiquidGlassButtonStyle())

            if !selectedIds.isEmpty {
                Text("\(selectedIds.count)件選択中")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                // Delete selected
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                        Text("削除")
                    }
                    .font(.caption)
                }
                .buttonStyle(LiquidGlassButtonStyle(isProminent: true, color: .red))
            } else {
                Spacer()
            }

            // Cancel selection mode
            Button("完了") {
                withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                    isSelectionMode = false
                    selectedIds.removeAll()
                }
            }
            .font(.caption)
            .buttonStyle(LiquidGlassButtonStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.12),
                            Color.accentColor.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
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
                Button("再読込") {
                    loadSummariesAsync()
                }
                .buttonStyle(LiquidGlassButtonStyle(isProminent: true, color: .red))
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
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedSummaries, id: \.date) { group in
                        Section {
                            ForEach(group.summaries) { summary in
                                TimelineSummaryRow(
                                    summary: summary,
                                    isSelectionMode: isSelectionMode,
                                    isSelected: summary.id.map { selectedIds.contains($0) } ?? false,
                                    onSelect: {
                                        if let id = summary.id {
                                            if selectedIds.contains(id) {
                                                selectedIds.remove(id)
                                            } else {
                                                selectedIds.insert(id)
                                            }
                                        }
                                    },
                                    onDelete: {
                                        deleteSummary(summary)
                                    }
                                )
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                    .onAppear {
                                        // Load more when reaching near the end
                                        if summary.id == summaries.last?.id && hasMoreData && !isLoadingMore {
                                            loadMoreSummaries()
                                        }
                                    }
                            }
                        } header: {
                            DateHeaderView(date: group.date, count: group.summaries.count)
                        }
                    }

                    // Loading more indicator
                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Helper Methods

    /// Update cached values when summaries change (performance optimization)
    private func updateCachedValues(from summaries: [Summary]) {
        let calendar = Calendar.current
        cachedDatesWithSummaries = Set(summaries.map { calendar.startOfDay(for: $0.timestamp) })
        cachedAvailableApps = Set(summaries.compactMap { $0.appName }).sorted()
    }

    private func loadSummariesAsync() {
        isLoading = true
        errorMessage = nil
        hasMoreData = true
        Task {
            do {
                let results = try await DatabaseService.shared.fetchRecentSummariesAsync(limit: pageSize)
                await MainActor.run {
                    summaries = results
                    isLoading = false
                    hasMoreData = results.count >= pageSize
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func loadMoreSummaries() {
        guard !isLoadingMore && hasMoreData else { return }
        isLoadingMore = true

        Task {
            do {
                let offset = summaries.count
                let results = try await DatabaseService.shared.fetchRecentSummariesAsync(limit: pageSize, offset: offset)
                await MainActor.run {
                    summaries.append(contentsOf: results)
                    isLoadingMore = false
                    hasMoreData = results.count >= pageSize
                }
            } catch {
                await MainActor.run {
                    isLoadingMore = false
                }
            }
        }
    }

    private func formatDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func copyAllAsText() {
        let text = summaries.map { formatSummaryAsText($0) }.joined(separator: "\n\n---\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showFeedback("全\(summaries.count)件をコピーしました")
    }

    private func copyTodayAsText() {
        Task {
            do {
                // Fetch all today's summaries from database (not just loaded ones)
                let allToday = try await DatabaseService.shared.fetchTodaySummariesAsync()

                await MainActor.run {
                    if allToday.isEmpty {
                        showFeedback("今日の履歴がありません")
                        return
                    }

                    let text = allToday.map { formatSummaryAsText($0) }.joined(separator: "\n\n---\n\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    showFeedback("今日の全\(allToday.count)件をコピーしました")
                }
            } catch {
                await MainActor.run {
                    showFeedback("コピーに失敗しました")
                }
            }
        }
    }

    private func copyFilteredAsMarkdown() {
        if filteredSummaries.isEmpty {
            showFeedback("コピーする履歴がありません")
            return
        }

        let text = filteredSummaries.map { formatSummaryAsMarkdown($0) }.joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showFeedback("\(filteredSummaries.count)件をコピーしました")
    }

    private func showFeedback(_ message: String) {
        copyFeedbackMessage = message
        showCopyFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopyFeedback = false
        }
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
        showFeedback("AI用にエクスポートしました (\(filteredSummaries.count)件)")
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
            print("[MainAppView] Cannot delete summary without ID")
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
                        print("[MainAppView] Deleted screenshot: \(path)")
                    }
                }

                // Remove from local array
                await MainActor.run {
                    summaries.removeAll { $0.id == summary.id }
                    searchResults.removeAll { $0.id == summary.id }
                }

                print("[MainAppView] Deleted summary ID: \(summaryId)")
            } catch {
                print("[MainAppView] Failed to delete summary: \(error)")
            }
        }
    }

    private func deleteSelectedSummaries() {
        let idsToDelete = selectedIds
        let summariesToDelete = summaries.filter { summary in
            guard let id = summary.id else { return false }
            return idsToDelete.contains(id)
        }

        Task {
            var deletedCount = 0
            let fileManager = FileManager.default

            for summary in summariesToDelete {
                guard let summaryId = summary.id else { continue }

                do {
                    // Delete from database
                    try await DatabaseService.shared.deleteSummaryAsync(id: summaryId)

                    // Delete screenshot file if exists
                    if let path = summary.screenshotPath,
                       fileManager.fileExists(atPath: path) {
                        try? fileManager.removeItem(atPath: path)
                    }

                    deletedCount += 1
                } catch {
                    print("[MainAppView] Failed to delete summary \(summaryId): \(error)")
                }
            }

            await MainActor.run {
                // Remove from local arrays
                summaries.removeAll { summary in
                    guard let id = summary.id else { return false }
                    return idsToDelete.contains(id)
                }
                searchResults.removeAll { summary in
                    guard let id = summary.id else { return false }
                    return idsToDelete.contains(id)
                }

                // Clear selection
                selectedIds.removeAll()
                isSelectionMode = false

                print("[MainAppView] Deleted \(deletedCount) summaries")
            }
        }
    }
}

#Preview {
    MainAppView()
}
