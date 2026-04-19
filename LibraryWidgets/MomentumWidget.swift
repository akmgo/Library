import Charts
import SwiftData
import SwiftUI
import WidgetKit

// 引入特定平台的图像框架
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - 新增内部数据结构，方便图表绑定日期

struct DailyReading: Identifiable {
    let date: Date
    let minutes: Double
    var id: Date {
        date
    }
}

// MARK: - 动能数据模型

struct MomentumEntry: TimelineEntry {
    let date: Date
    let dailyData: [DailyReading] // ✨ 改用带日期的数据组
    let totalDays: Int
    let totalMinutes: Int
    let maxMinutes: Int
    let avgMinutes: Int
}

// MARK: - 数据提供者

struct MomentumProvider: TimelineProvider {
    func placeholder(in context: Context) -> MomentumEntry {
        let cal = Calendar.current
        let today = Date()
        let dummyData = (0..<14).map { i -> DailyReading in
            DailyReading(date: cal.date(byAdding: .day, value: i - 13, to: today)!, minutes: Double.random(in: 0 ... 100))
        }
        return MomentumEntry(date: today, dailyData: dummyData, totalDays: 12, totalMinutes: 605, maxMinutes: 120, avgMinutes: 43)
    }

    func getSnapshot(in context: Context, completion: @escaping (MomentumEntry) -> ()) {
        Task { @MainActor in completion(fetchRealData()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            let entry = fetchRealData()
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    @MainActor
    private func fetchRealData() -> MomentumEntry {
        let dbContext = SharedDatabase.shared.container.mainContext
        do {
            let allRecords = try dbContext.fetch(FetchDescriptor<ReadingRecord>())
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let startDate = cal.date(byAdding: .day, value: -13, to: today)!

            var dailyMap: [Date: Double] = [:]
            for record in allRecords {
                guard let validDate = record.date else { continue }
                let recordDay = cal.startOfDay(for: validDate)
                if recordDay >= startDate && recordDay <= today {
                    dailyMap[recordDay, default: 0] += (record.readingDuration / 60.0)
                }
            }

            var last14DaysData: [DailyReading] = []
            var daysRead = 0
            var maxMin = 0.0
            var totalMin = 0.0

            for i in 0..<14 {
                let d = cal.date(byAdding: .day, value: i, to: startDate)!
                let mins = dailyMap[d] ?? 0.0
                last14DaysData.append(DailyReading(date: d, minutes: mins))

                if mins > 0 { daysRead += 1 }
                if mins > maxMin { maxMin = mins }
                totalMin += mins
            }

            let avgMin = daysRead > 0 ? (totalMin / Double(daysRead)) : 0.0

            return MomentumEntry(
                date: Date(),
                dailyData: last14DaysData,
                totalDays: daysRead,
                totalMinutes: Int(totalMin),
                maxMinutes: Int(maxMin),
                avgMinutes: Int(avgMin)
            )
        } catch {
            return MomentumEntry(date: Date(), dailyData: [], totalDays: 0, totalMinutes: 0, maxMinutes: 0, avgMinutes: 0)
        }
    }
}

// MARK: - 极简动能视图

struct MomentumWidgetView: View {
    var entry: MomentumProvider.Entry

    var body: some View {
        VStack(spacing: 0) {
            // ================= 上半部：四大横排核心指标 =================
            HStack(alignment: .center, spacing: 0) {
                MomentumStat(title: "阅读天数", value: "\(entry.totalDays)", unit: "天")
                Spacer(minLength: 5)
                MomentumStat(title: "总计时间", value: "\(entry.totalMinutes)", unit: "分")
                Spacer(minLength: 5)
                MomentumStat(title: "单日最高", value: "\(entry.maxMinutes)", unit: "分")
                Spacer(minLength: 5)
                MomentumStat(title: "日均阅读", value: "\(entry.avgMinutes)", unit: "分")
            }
            .padding(.bottom, 12)

            Spacer(minLength: 0)

            // ================= 下半部：扁平流体动能图 =================
            Chart {
                ForEach(entry.dailyData) { item in
                    // 渐变面积图
                    AreaMark(
                        x: .value("Day", item.date),
                        y: .value("Minutes", item.minutes)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(
                        colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    ))

                    // 顶部线条
                    LineMark(
                        x: .value("Day", item.date),
                        y: .value("Minutes", item.minutes)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
            }
            .chartYAxis(.hidden)
            // 保留了优雅的横坐标，改为显示具体的日期数字
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day())
                        .font(.system(size: 9, weight: .bold))
                        // ✨ 明确告诉编译器这是 Color.secondary
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 80) // 稍微加高 5 像素给文字留出空间
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

/// 子组件：紧凑型微数据块
private struct MomentumStat: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
    }
}

// MARK: - 注册组件

struct MomentumWidget: Widget {
    let kind: String = "MomentumWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MomentumProvider()) { entry in
            MomentumWidgetView(entry: entry)
        }
        .configurationDisplayName("双周动能")
        .description("展示近 14 天的阅读时长趋势与核心指标。")
        .supportedFamilies([.systemMedium])
    }
}
