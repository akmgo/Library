import Charts
import SwiftData
import SwiftUI
import WidgetKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct DailyReading: Identifiable {
    let date: Date
    let minutes: Double
    var id: Date { date }
}

struct MomentumEntry: TimelineEntry {
    let date: Date
    let dailyData: [DailyReading]
    let totalDays: Int
    let totalMinutes: Int
    let maxMinutes: Int
    let avgMinutes: Int
}

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
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let startDate = cal.date(byAdding: .day, value: -13, to: today)!

            let descriptor = FetchDescriptor<ReadingRecord>(
                predicate: #Predicate { $0.date >= startDate }
            )
            let recentRecords = try dbContext.fetch(descriptor)

            var dailyMap: [Date: Double] = [:]
            for record in recentRecords {
                let recordDay = cal.startOfDay(for: record.date)
                if recordDay <= today {
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
                date: Date(), dailyData: last14DaysData, totalDays: daysRead, totalMinutes: Int(totalMin), maxMinutes: Int(maxMin), avgMinutes: Int(avgMin)
            )
        } catch {
            return MomentumEntry(date: Date(), dailyData: [], totalDays: 0, totalMinutes: 0, maxMinutes: 0, avgMinutes: 0)
        }
    }
}

struct MomentumWidgetView: View {
    var entry: MomentumProvider.Entry

    var body: some View {
        VStack(spacing: 0) {
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

            Chart {
                ForEach(entry.dailyData) { item in
                    AreaMark(
                        x: .value("Day", item.date),
                        y: .value("Minutes", item.minutes)
                    )
                    .interpolationMethod(.catmullRom)
                    // ✨ UI优化：更换为更通透的高级渐变
                    .foregroundStyle(LinearGradient(
                        colors: [Color.indigo.opacity(0.4), Color.cyan.opacity(0.05), .clear],
                        startPoint: .top, endPoint: .bottom
                    ))

                    LineMark(
                        x: .value("Day", item.date),
                        y: .value("Minutes", item.minutes)
                    )
                    .interpolationMethod(.catmullRom)
                    // ✨ UI优化：线条也使用渐变色
                    .foregroundStyle(LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 80)
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
                    .monospacedDigit() // ✨ UI优化：防止数字跳动导致的面板闪烁
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
    }
}

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
