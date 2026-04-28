import SwiftData
import SwiftUI
import WidgetKit

struct HeatmapColumnData: Identifiable { let id: Int; let days: [HeatmapDayData] }
struct HeatmapDayData: Identifiable { let id = UUID(); let intensity: Double; let isFuture: Bool }

struct HeatmapEntry: TimelineEntry {
    let date: Date
    let columns: [HeatmapColumnData]
    let isEmpty: Bool // ✨ 标记是否完全没有数据
}

struct HeatmapProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeatmapEntry {
        HeatmapEntry(
            date: Date(),
            columns: (0..<22).map { i in HeatmapColumnData(id: i, days: (0..<7).map { _ in HeatmapDayData(intensity: Double.random(in: 0...1), isFuture: false) }) },
            isEmpty: false
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
            var cal = Calendar.current
            cal.firstWeekday = 2
            let today = cal.startOfDay(for: Date())
            
            let columnsCount = 22
            let daysToSubtract = ((cal.component(.weekday, from: today) + 5) % 7)
            let currentWeekStart = cal.date(byAdding: .day, value: -daysToSubtract, to: today)!
            let startDate = cal.date(byAdding: .weekOfYear, value: -(columnsCount - 1), to: currentWeekStart)!

            let descriptor = FetchDescriptor<ReadingRecord>(
                predicate: #Predicate { $0.date >= startDate }
            )
            let recentRecords = try dbContext.fetch(descriptor)

            var dailyDurations: [Date: TimeInterval] = [:]
            for record in recentRecords {
                dailyDurations[cal.startOfDay(for: record.date), default: 0] += record.readingDuration
            }
            
            var cols: [HeatmapColumnData] = []
            for weekOffset in 0..<columnsCount {
                var days: [HeatmapDayData] = []
                for dayOffset in 0..<7 {
                    let date = cal.date(byAdding: .day, value: weekOffset * 7 + dayOffset, to: startDate)!
                    let duration = dailyDurations[date] ?? 0
                    let isFuture = date > today
                    let intensity = isFuture ? 0.0 : (duration > 0 ? min((duration / 3600.0) * 0.7 + 0.3, 1.0) : 0.0)
                    days.append(HeatmapDayData(intensity: intensity, isFuture: isFuture))
                }
                cols.append(HeatmapColumnData(id: weekOffset, days: days))
            }
            
            return HeatmapEntry(date: Date(), columns: cols, isEmpty: recentRecords.isEmpty)
        } catch {
            return HeatmapEntry(date: Date(), columns: [], isEmpty: true)
        }
    }
}

struct HeatmapWidgetView: View {
    var entry: HeatmapProvider.Entry

    var body: some View {
        GeometryReader { geo in
            let columns: CGFloat = CGFloat(entry.columns.isEmpty ? 22 : entry.columns.count)
            let spacing: CGFloat = 3.5
            let squareSize = (geo.size.width - (columns - 1) * spacing) / columns
            
            ZStack {
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
                .opacity(entry.isEmpty ? 0.2 : 1.0) // 如果没有数据，图表变暗淡做背景
                
                // ✨ UI优化：极致优雅的空状态
                if entry.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                        Text("去沉淀点滴时间")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
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

struct YearlyHeatmapWidget: Widget {
    let kind: String = "YearlyHeatmapWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeatmapProvider()) { entry in
            HeatmapWidgetView(entry: entry)
        }
        .configurationDisplayName("打卡密度")
        .description("在桌面上回顾你纯粹的阅读热力图。")
        .supportedFamilies([.systemMedium])
    }
}
