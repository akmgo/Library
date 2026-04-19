import SwiftData
import SwiftUI
import WidgetKit

// ✨ 引入特定平台的图像与颜色框架
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - 数据模型

struct DashboardEntry: TimelineEntry {
    let date: Date
    let weekCount: Int
    let monthlyDays: Int
    let yearlyCount: Int

    // ✨ 馆藏进度专属：已读数量 / 书库总数
    let totalFinished: Int
    let totalBooksInLibrary: Int

    let todayMinutes: Int

    // 目标（从 JSON 读取的自定义目标）
    let dailyGoal: Int
    let weekTarget: Int
    let monthTarget: Int
    let yearTarget: Int
}

// MARK: - 数据提供者

struct DashboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(date: Date(), weekCount: 3, monthlyDays: 12, yearlyCount: 25, totalFinished: 25, totalBooksInLibrary: 42, todayMinutes: 15, dailyGoal: 30, weekTarget: 7, monthTarget: 30, yearTarget: 50)
    }

    func getSnapshot(in context: Context, completion: @escaping (DashboardEntry) -> ()) {
        Task { @MainActor in completion(fetchRealData()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            let entry = fetchRealData()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    @MainActor
    private func fetchRealData() -> DashboardEntry {
        let context = SharedDatabase.shared.container.mainContext
        do {
            let allBooks = try context.fetch(FetchDescriptor<Book>())
            let allRecords = try context.fetch(FetchDescriptor<ReadingRecord>())
            
            // ✨ 核心替换：直接从 SwiftData 中提取最新的 UserConfig，抛弃 JSON！
                        let configDesc = FetchDescriptor<UserConfig>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
                        let globalConfig = (try? context.fetch(configDesc))?.first ?? UserConfig() // 查不到就给默认值
            
            let calendar = Calendar.current; let today = Date()
            let currentYear = calendar.component(.year, from: today)
            let currentMonth = calendar.component(.month, from: today)

            // 1. 本周打卡天数
            var tempCalendar = calendar; tempCalendar.firstWeekday = 2; var tempWeekCount = 0
            if let startOfWeek = tempCalendar.date(from: tempCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) {
                for i in 0 ..< 7 {
                    if let dayDate = tempCalendar.date(byAdding: .day, value: i, to: startOfWeek) {
                        if allRecords.contains(where: { tempCalendar.isDate($0.date ?? Date.distantPast, inSameDayAs: dayDate) }) { tempWeekCount += 1 }
                    }
                }
            }

            // 2. 本月阅读天数
            let thisMonthRecords = allRecords.filter {
                let safeDate = $0.date ?? Date.distantPast
                return calendar.component(.year, from: safeDate) == currentYear && calendar.component(.month, from: safeDate) == currentMonth
            }
            let monthlyDays = Set(thisMonthRecords.map { calendar.component(.day, from: $0.date ?? Date.distantPast) }).count

            // 3. 年度已读完数量
            let yearlyCount = allBooks.filter { $0.status == .finished && calendar.component(.year, from: $0.endTime ?? today) == currentYear }.count

            // ==========================================
            // ✨ 4. 实时计算：全局通关率（取代了原先的手动目标）
            // ==========================================
            let totalFinishedCount = allBooks.filter { $0.status == .finished }.count
            let totalLibraryCount = allBooks.count // 书库真实总量

            // 5. 今日阅读进度逻辑
            let todayRecords = allRecords.filter { calendar.isDate($0.date ?? Date.distantPast, inSameDayAs: today) }
            let todaySeconds = todayRecords.reduce(0) { $0 + Int($1.readingDuration) }
            let todayMinutes = todaySeconds / 60

            return DashboardEntry(
                date: today,
                weekCount: tempWeekCount,
                monthlyDays: monthlyDays,
                yearlyCount: yearlyCount,
                totalFinished: totalFinishedCount, // 传入实时已读数
                totalBooksInLibrary: totalLibraryCount, // 传入实时总藏书
                todayMinutes: todayMinutes,
                dailyGoal: globalConfig.dailyReadingGoal,
                weekTarget: 7,
                monthTarget: 30,
                yearTarget: globalConfig.yearlyBookGoal
            )
        } catch {
            return DashboardEntry(date: Date(), weekCount: 0, monthlyDays: 0, yearlyCount: 0, totalFinished: 0, totalBooksInLibrary: 0, todayMinutes: 0, dailyGoal: 30, weekTarget: 7, monthTarget: 30, yearTarget: 50)
        }
    }
}

// MARK: - 主视图 (极致利用原生边距)

struct DashboardWidgetEntryView: View {
    var entry: DashboardProvider.Entry

    var body: some View {
        VStack(spacing: 0) {
            // ================= 顶部：四大圆环看板 =================
            HStack(alignment: .center) {
                WidgetMicroMetric(title: "本周打卡", current: entry.weekCount, target: entry.weekTarget, color: .pink, icon: "flame.fill")
                Spacer()
                WidgetMicroMetric(title: "本月历程", current: entry.monthlyDays, target: entry.monthTarget, color: .mint, icon: "calendar")
                Spacer()
                WidgetMicroMetric(title: "年度阅卷", current: entry.yearlyCount, target: entry.yearTarget, color: .cyan, icon: "book.closed.fill")
                Spacer()
                // ✨ 馆藏进度：使用实时数据，更换排书图标
                WidgetMicroMetric(title: "馆藏进度", current: entry.totalFinished, target: entry.totalBooksInLibrary, color: .indigo, icon: "books.vertical.fill")
            }

            Spacer()

            // ================= 底部：今日阅读进度 =================
            VStack(spacing: 8) {
                HStack(alignment: .bottom) {
                    Label("今日阅读进度", systemImage: "book.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)

                    Spacer()

                    if entry.todayMinutes >= entry.dailyGoal {
                        Text("🎉 目标达成")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                    } else {
                        Text("\(entry.todayMinutes) / \(entry.dailyGoal) 分钟")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(.blue)
                    }
                }

                let safeProgress = min(max(Double(entry.todayMinutes) / Double(entry.dailyGoal), 0.0), 1.0)
                ProgressView(value: safeProgress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
            }
        }
        .frame(maxHeight: .infinity)
        .containerBackground(for: .widget) {
            #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
            #else
            Color(uiColor: .systemBackground)
            #endif
        }
    }
}

// MARK: - 子组件：微型状态圆环 (尺寸 50)

private struct WidgetMicroMetric: View {
    let title: String
    let current: Int
    let target: Int
    let color: Color
    let icon: String

    var body: some View {
        // ✨ 安全计算进度：防止除以 0。当书库为空（target=0）时，将分母按 1 算，圆环进度为 0%，但 UI 依然优雅显示 "0/0"
        let safeTarget = max(Double(target), 1.0)
        let progress = min(Double(current) / safeTarget, 1.0)

        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 5.0)
                Circle()
                    .trim(from: 0, to: max(progress, 0.001))
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 5.0, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(color)
            }
            .frame(width: 50, height: 50)

            VStack(spacing: 2) {
                Text("\(current)/\(target)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 注册组件

struct DesktopDashboardWidget: Widget {
    let kind: String = "DesktopDashboardWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardProvider()) { entry in
            DashboardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("阅读统计看板")
        .description("展示本周、本月、年度及馆藏进度的阅读统计。")
        .supportedFamilies([.systemMedium])
    }
}
