import SwiftData
import SwiftUI
import WidgetKit

// 引入特定平台的图像框架
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - 数据模型
struct HeatmapColumnData: Identifiable { let id: Int; let days: [HeatmapDayData] }
struct HeatmapDayData: Identifiable { let id = UUID(); let intensity: Double; let isFuture: Bool }

struct HeatmapEntry: TimelineEntry {
    let date: Date
    let columns: [HeatmapColumnData]
}

// MARK: - 数据提供者
struct HeatmapProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeatmapEntry {
        // 占位符展示 22 列随机热力图
        HeatmapEntry(
            date: Date(),
            columns: (0..<22).map { i in HeatmapColumnData(id: i, days: (0..<7).map { _ in HeatmapDayData(intensity: Double.random(in: 0...1), isFuture: false) }) }
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HeatmapEntry) -> ()) {
        Task { @MainActor in completion(fetchRealData()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            let entry = fetchRealData()
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    @MainActor
    private func fetchRealData() -> HeatmapEntry {
        let dbContext = SharedDatabase.shared.container.mainContext
        do {
            let allRecords = try dbContext.fetch(FetchDescriptor<ReadingRecord>())
            var cal = Calendar.current; cal.firstWeekday = 2; let today = cal.startOfDay(for: Date())

            // 1. 汇总每天的阅读时长
            var dailyDurations: [Date: TimeInterval] = [:]
            for record in allRecords {
                guard let validDate = record.date else { continue }
                dailyDurations[cal.startOfDay(for: validDate), default: 0] += record.readingDuration
            }
            
            // 2. 构建 22 周 (中尺寸组件最佳视觉比例) 热力图矩阵
            let columnsCount = 22
            let daysToSubtract = ((cal.component(.weekday, from: today) + 5) % 7)
            let currentWeekStart = cal.date(byAdding: .day, value: -daysToSubtract, to: today)!
            let startDate = cal.date(byAdding: .weekOfYear, value: -(columnsCount - 1), to: currentWeekStart)!

            var cols: [HeatmapColumnData] = []
            for weekOffset in 0..<columnsCount {
                var days: [HeatmapDayData] = []
                for dayOffset in 0..<7 {
                    let date = cal.date(byAdding: .day, value: weekOffset * 7 + dayOffset, to: startDate)!
                    let duration = dailyDurations[date] ?? 0
                    let isFuture = date > today
                    // 动态上色：根据时长加深颜色
                    let intensity = isFuture ? 0.0 : (duration > 0 ? min((duration / 3600.0) * 0.7 + 0.3, 1.0) : 0.0)
                    days.append(HeatmapDayData(intensity: intensity, isFuture: isFuture))
                }
                cols.append(HeatmapColumnData(id: weekOffset, days: days))
            }
            
            return HeatmapEntry(date: Date(), columns: cols)
        } catch {
            return HeatmapEntry(date: Date(), columns: [])
        }
    }
}

// MARK: - 极简纯粹的热力图视图
struct HeatmapWidgetView: View {
    var entry: HeatmapProvider.Entry

    var body: some View {
        GeometryReader { geo in
            // 动态计算方块尺寸：列数默认 22，间距 3.5
            let columns: CGFloat = CGFloat(entry.columns.isEmpty ? 22 : entry.columns.count)
            let spacing: CGFloat = 3.5
            let squareSize = (geo.size.width - (columns - 1) * spacing) / columns
            
            HStack(spacing: spacing) {
                ForEach(entry.columns) { column in
                    VStack(spacing: spacing) {
                        ForEach(column.days) { day in
                            let baseColor = day.intensity > 0 ? Color.indigo.opacity(day.intensity) : Color.secondary.opacity(0.12)
                            
                            RoundedRectangle(cornerRadius: squareSize * 0.25, style: .continuous)
                                .fill(day.isFuture ? Color.clear : baseColor)
                                .frame(width: squareSize, height: squareSize)
                        }
                    }
                }
            }
            // 利用 alignment: .center 确保整个矩阵在可用空间内绝对居中
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .containerBackground(for: .widget) {
            #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
            #else
            Color(uiColor: .systemBackground)
            #endif
        }
    }
}

// MARK: - 注册组件
struct YearlyHeatmapWidget: Widget {
    let kind: String = "YearlyHeatmapWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeatmapProvider()) { entry in
            HeatmapWidgetView(entry: entry)
        }
        .configurationDisplayName("打卡密度")
        .description("在桌面上回顾你纯粹的阅读热力图。")
        // ✨ 改回最完美的中号尺寸
        .supportedFamilies([.systemMedium])
    }
}
