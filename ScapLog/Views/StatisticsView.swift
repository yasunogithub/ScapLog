//
//  StatisticsView.swift
//  ScapLog
//
//  統計ダッシュボード
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @State private var stats: SummaryStatistics?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("統計")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    loadStatistics()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(GlassButtonStyle())
            }
            .padding()
            .liquidGlassHeader()

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let stats = stats {
                ScrollView {
                    VStack(spacing: 20) {
                        // Overview cards
                        HStack(spacing: 16) {
                            StatCard(
                                title: "総キャプチャ数",
                                value: "\(stats.totalCount)",
                                icon: "photo.stack",
                                color: .blue
                            )
                            StatCard(
                                title: "今日",
                                value: "\(stats.todayCount)",
                                icon: "clock",
                                color: .green
                            )
                            StatCard(
                                title: "平均/日",
                                value: String(format: "%.1f", stats.averagePerDay),
                                icon: "chart.line.uptrend.xyaxis",
                                color: .orange
                            )
                        }

                        // Date range
                        if let firstDate = stats.firstDate {
                            GlassGroupBox(title: "期間", icon: "calendar") {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("開始日")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(formatDate(firstDate))
                                            .font(.headline)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("経過日数")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(stats.daysSinceFirst)日")
                                            .font(.headline)
                                    }
                                }
                            }
                        }

                        // App usage chart
                        if !stats.appUsage.isEmpty {
                            GlassGroupBox(title: "アプリ使用状況", icon: "app.badge") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(stats.appUsage.sorted { $0.value > $1.value }), id: \.key) { app, count in
                                        AppUsageRow(
                                            appName: app,
                                            count: count,
                                            maxCount: stats.appUsage.values.max() ?? 1
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                Spacer()
                Text("データがありません")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .background(Color.clear)
        .onAppear {
            loadStatistics()
        }
    }

    private func loadStatistics() {
        isLoading = true
        Task {
            do {
                let result = try DatabaseService.shared.getStatistics()
                await MainActor.run {
                    stats = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .liquidGlassCard(cornerRadius: 12)
    }
}

// MARK: - App Usage Row

struct AppUsageRow: View {
    let appName: String
    let count: Int
    let maxCount: Int

    var progress: Double {
        Double(count) / Double(maxCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(appName)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.1))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue.opacity(0.7))
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StatisticsView()
}
