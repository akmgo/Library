import SwiftData
import SwiftUI
import WidgetKit

// MARK: - 1. 专属数据模型
struct StatsGridEntry: TimelineEntry {
    let date: Date
    let weekCount: Int
    let weekTarget: Int
    let monthlyDays: Int
    let monthTarget: Int
    let yearlyCount: Int
    let yearTarget: Int
    let libraryRead: Int
    let libraryTotal: Int
}

// MARK: - 2. 专属数据引擎 (真实读取 SwiftData)
struct StatsGridProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsGridEntry { mockEntry() }
    
    func getSnapshot(in context: Context, completion: @escaping (StatsGridEntry) -> ()) {
        Task { @MainActor in completion(await fetchRealData()) }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            let entry = await fetchRealData()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }
    
    @MainActor
    private func fetchRealData() async -> StatsGridEntry {
        let context = SharedDatabase.shared.container.mainContext
        do {
            let allBooks = try context.fetch(FetchDescriptor<Book>())
            let allRecords = try context.fetch(FetchDescriptor<ReadingRecord>())
            
            let configDesc = FetchDescriptor<UserConfig>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            let globalConfig = (try? context.fetch(configDesc))?.first ?? UserConfig()
            
            let calendar = Calendar.current; let today = Date()
            let currentYear = calendar.component(.year, from: today)
            let currentMonth = calendar.component(.month, from: today)

            var tempCalendar = calendar; tempCalendar.firstWeekday = 2; var tempWeekCount = 0
            if let startOfWeek = tempCalendar.date(from: tempCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) {
                for i in 0 ..< 7 {
                    if let dayDate = tempCalendar.date(byAdding: .day, value: i, to: startOfWeek) {
                        if allRecords.contains(where: { tempCalendar.isDate($0.date ?? Date.distantPast, inSameDayAs: dayDate) }) { tempWeekCount += 1 }
                    }
                }
            }

            let thisMonthRecords = allRecords.filter {
                let safeDate = $0.date ?? Date.distantPast
                return calendar.component(.year, from: safeDate) == currentYear && calendar.component(.month, from: safeDate) == currentMonth
            }
            let monthlyDays = Set(thisMonthRecords.map { calendar.component(.day, from: $0.date ?? Date.distantPast) }).count

            let yearlyCount = allBooks.filter { $0.status == .finished && calendar.component(.year, from: $0.endTime ?? today) == currentYear }.count
            let totalFinishedCount = allBooks.filter { $0.status == .finished }.count
            let totalLibraryCount = allBooks.count

            return StatsGridEntry(
                date: today,
                weekCount: tempWeekCount,
                weekTarget: 7,
                monthlyDays: monthlyDays,
                monthTarget: 30,
                yearlyCount: yearlyCount,
                yearTarget: globalConfig.yearlyBookGoal,
                libraryRead: totalFinishedCount,
                libraryTotal: totalLibraryCount
            )
        } catch {
            return mockEntry()
        }
    }
    
    private func mockEntry() -> StatsGridEntry {
        StatsGridEntry(date: Date(), weekCount: 5, weekTarget: 7, monthlyDays: 21, monthTarget: 30, yearlyCount: 12, yearTarget: 50, libraryRead: 45, libraryTotal: 120)
    }
}

// MARK: - 3. UI 视图
struct StatsGridWidgetView: View {
    var entry: StatsGridEntry
    
    var body: some View {
        VStack {
            HStack {
                PureRingMetric(current: entry.weekCount, target: entry.weekTarget, color: .pink, icon: "flame.fill")
                PureRingMetric(current: entry.monthlyDays, target: entry.monthTarget, color: .mint, icon: "calendar")
            }
            HStack {
                PureRingMetric(current: entry.yearlyCount, target: entry.yearTarget, color: .cyan, icon: "book.closed.fill")
                PureRingMetric(current: entry.libraryRead, target: entry.libraryTotal, color: .indigo, icon: "books.vertical.fill")
            }
        }
        // ✨ 核心修复：复用扩展的自适应背景
        .containerBackground(Color.adaptiveWidgetBackground, for: .widget)
    }
}

// MARK: - 专属子组件：无字纯粹放大圆环
private struct PureRingMetric: View {
    let current: Int
    let target: Int
    let color: Color
    let icon: String

    var body: some View {
        let safeTarget = max(Double(target), 1.0)
        let progress = min(Double(current) / safeTarget, 1.0)

        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 6.0)
            
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 6.0, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(4)
    }
}

// MARK: - 4. 组件注册入口
struct StatsGridWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StatsGridWidget", provider: StatsGridProvider()) { entry in
            StatsGridWidgetView(entry: entry)
        }
        .configurationDisplayName("阅读仪表盘")
        .description("展示四个维度的纯粹阅读动能圆环。")
        .supportedFamilies([.systemSmall])
    }
}

#Preview("阅读仪表盘", as: .systemSmall) {
    StatsGridWidget()
} timeline: {
    StatsGridEntry(date: Date(), weekCount: 5, weekTarget: 7, monthlyDays: 21, monthTarget: 30, yearlyCount: 12, yearTarget: 50, libraryRead: 45, libraryTotal: 120)
}
