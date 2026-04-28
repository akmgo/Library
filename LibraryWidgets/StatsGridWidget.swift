import SwiftData
import SwiftUI
import WidgetKit

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
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let currentYear = calendar.component(.year, from: today)
            let currentMonth = calendar.component(.month, from: today)

            // 配置提取
            var configDesc = FetchDescriptor<UserConfig>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            configDesc.fetchLimit = 1
            let globalConfig = (try? context.fetch(configDesc))?.first ?? UserConfig()

            // ✨ 性能优化：单次遍历搞定书籍统计
            let allBooks = try context.fetch(FetchDescriptor<Book>())
            var yearlyCount = 0
            var libraryRead = 0
            for book in allBooks {
                if book.status == .finished {
                    libraryRead += 1
                    if let eTime = book.endTime, calendar.component(.year, from: eTime) == currentYear {
                        yearlyCount += 1
                    }
                }
            }
            let libraryTotal = allBooks.count

            // ✨ 性能优化：单次遍历搞定本周、本月打卡天数统计 (绝对不嵌套使用 contains/filter)
            let allRecords = try context.fetch(FetchDescriptor<ReadingRecord>())
            var tempCalendar = calendar
            tempCalendar.firstWeekday = 2
            let startOfWeek = tempCalendar.date(from: tempCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today

            var weekDaysSet = Set<Int>()
            var monthDaysSet = Set<Int>()

            for record in allRecords {
                let recDate = calendar.startOfDay(for: record.date)
                // 算本周
                if recDate >= startOfWeek && recDate <= today {
                    weekDaysSet.insert(calendar.ordinality(of: .day, in: .era, for: recDate) ?? 0)
                }
                // 算本月
                if calendar.component(.year, from: recDate) == currentYear && calendar.component(.month, from: recDate) == currentMonth {
                    monthDaysSet.insert(calendar.component(.day, from: recDate))
                }
            }

            return StatsGridEntry(
                date: today,
                weekCount: weekDaysSet.count, weekTarget: 7,
                monthlyDays: monthDaysSet.count, monthTarget: 30,
                yearlyCount: yearlyCount, yearTarget: globalConfig.yearlyBookGoal,
                libraryRead: libraryRead, libraryTotal: libraryTotal
            )
        } catch {
            return mockEntry()
        }
    }
    
    private func mockEntry() -> StatsGridEntry {
        StatsGridEntry(date: Date(), weekCount: 5, weekTarget: 7, monthlyDays: 21, monthTarget: 30, yearlyCount: 12, yearTarget: 50, libraryRead: 45, libraryTotal: 120)
    }
}

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
        .containerBackground(Color.adaptiveWidgetBackground, for: .widget)
    }
}

private struct PureRingMetric: View {
    let current: Int
    let target: Int
    let color: Color
    let icon: String

    var body: some View {
        let safeTarget = max(Double(target), 1.0)
        let progress = min(Double(current) / safeTarget, 1.0)

        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 6.0)
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
