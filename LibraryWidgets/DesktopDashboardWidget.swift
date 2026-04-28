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

/// 承载中号数据大盘状态的小组件时间线实体。
struct DashboardEntry: TimelineEntry {
    let date: Date
    let weekCount: Int
    let monthlyDays: Int
    let yearlyCount: Int

    // ✨ 馆藏进度专属：已读数量 / 书库总数
    let totalFinished: Int
    let totalBooksInLibrary: Int

    let todayMinutes: Int

    // 目标（从 SwiftData 读取的自定义目标）
    let dailyGoal: Int
    let weekTarget: Int
    let monthTarget: Int
    let yearTarget: Int
}

/// 为中号数据大盘提供时间线数据的核心引擎。
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
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let currentYear = calendar.component(.year, from: today)
            let currentMonth = calendar.component(.month, from: today)
            
            // ✨ 优化 1：配置抓取限制为 1 条，极速返回
            var configDesc = FetchDescriptor<UserConfig>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
            configDesc.fetchLimit = 1
            let globalConfig = (try? context.fetch(configDesc))?.first ?? UserConfig()

            // ✨ 优化 2：单次遍历完成书籍统计 (O(N))
            let allBooks = try context.fetch(FetchDescriptor<Book>())
            var totalFinishedCount = 0
            var yearlyCount = 0
            
            for book in allBooks {
                if book.status == .finished {
                    totalFinishedCount += 1
                    if let endTime = book.endTime, calendar.component(.year, from: endTime) == currentYear {
                        yearlyCount += 1
                    }
                }
            }
            let totalLibraryCount = allBooks.count

            // ✨ 优化 3：单次遍历完成记录统计，拒绝在循环中使用 filter/contains
            let allRecords = try context.fetch(FetchDescriptor<ReadingRecord>())
            
            var tempCalendar = calendar
            tempCalendar.firstWeekday = 2 // 周一为每周第一天
            let startOfWeek = tempCalendar.date(from: tempCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today

            var weekDaysSet = Set<Int>()
            var monthDaysSet = Set<Int>()
            var todaySeconds: TimeInterval = 0

            for record in allRecords {
                let recDate = calendar.startOfDay(for: record.date)
                
                // 1. 今日时长
                if recDate == today { todaySeconds += record.readingDuration }
                
                // 2. 本周打卡天数
                if recDate >= startOfWeek && recDate <= today {
                    weekDaysSet.insert(calendar.ordinality(of: .day, in: .era, for: recDate) ?? 0)
                }
                
                // 3. 本月阅读天数
                if calendar.component(.year, from: recDate) == currentYear && calendar.component(.month, from: recDate) == currentMonth {
                    monthDaysSet.insert(calendar.component(.day, from: recDate))
                }
            }

            return DashboardEntry(
                date: Date(),
                weekCount: weekDaysSet.count,
                monthlyDays: monthDaysSet.count,
                yearlyCount: yearlyCount,
                totalFinished: totalFinishedCount,
                totalBooksInLibrary: totalLibraryCount,
                todayMinutes: Int(todaySeconds / 60),
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

/// 中号尺寸 (`.systemMedium`) 的阅读统计看板视图。
///
/// 上方并排呈现四个微型环形图表，下方辅以今日进度的线性指示器。
// MARK: - 主视图 (极致利用原生边距)

/// 中号尺寸 (`.systemMedium`) 的阅读统计看板视图。
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
                            .foregroundColor(.cyan) // 配合渐变色调
                    } else {
                        Text("\(entry.todayMinutes) / \(entry.dailyGoal) 分钟")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .monospacedDigit() // ✨ 优化点 1：等宽数字，彻底防止数字跳动导致的 UI 位移抖动
                            .foregroundColor(.cyan)
                    }
                }

                let safeProgress = min(max(Double(entry.todayMinutes) / Double(entry.dailyGoal), 0.0), 1.0)
                
                ProgressView(value: safeProgress)
                    .progressViewStyle(.linear)
                    // ✨ 优化点 2：使用更高级的渐变色替代单调的纯蓝
                    .tint(LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing))
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

/// 为看板定制的微型带 Icon 的环形图表构建器。
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

/// 中号阅读统计看板组件注册入口。
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
