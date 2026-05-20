import SwiftData
import SwiftUI
import WidgetKit

// MARK: - 1. 专属数据模型

/// 小号七日动能柱状图实体模型。
struct MomentumChartEntry: TimelineEntry {
    let date: Date
    let weekDurations: [Double]
    let weekTotalHours: Int
    let weeklyDays: Int
}

/// 获取最近 7 天沉浸阅读时长的柱状分布数据。
struct MomentumChartProvider: TimelineProvider {
    func placeholder(in context: Context) -> MomentumChartEntry { mockEntry() }
    
    func getSnapshot(in context: Context, completion: @escaping (MomentumChartEntry) -> ()) {
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
    private func fetchRealData() async -> MomentumChartEntry {
        let context = SharedDatabase.shared.container.mainContext
        do {
            let allRecords = try context.fetch(FetchDescriptor<ReadingSession>())
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            // ✨ 优化：声明定长数组，直接计算索引填入，彻底消灭嵌套循环
            var weekSeconds: [TimeInterval] = Array(repeating: 0.0, count: 7)
            
            for record in allRecords {
                let recDate = calendar.startOfDay(for: record.date)
                // 计算该记录是几天前
                let components = calendar.dateComponents([.day], from: recDate, to: today)
                if let daysAgo = components.day, daysAgo >= 0 && daysAgo < 7 {
                    weekSeconds[6 - daysAgo] += record.duration
                }
            }
            
            var weeklyDays = 0
            var totalSeconds = 0.0
            var weekDurations: [Double] = []
            
            for seconds in weekSeconds {
                if seconds > 0 { weeklyDays += 1 }
                totalSeconds += seconds
                weekDurations.append(seconds / 3600.0)
            }
            
            return MomentumChartEntry(
                date: Date(),
                weekDurations: weekDurations,
                weekTotalHours: Int(totalSeconds / 3600.0),
                weeklyDays: weeklyDays
            )
        } catch {
            return mockEntry()
        }
    }
    
    private func mockEntry() -> MomentumChartEntry {
        MomentumChartEntry(date: Date(), weekDurations: [1.2, 0.5, 2.0, 0.0, 1.5, 3.1, 0.8], weekTotalHours: 12, weeklyDays: 5)
    }
}
// MARK: - 3. UI 视图

/// 小尺寸 (`.systemSmall`) 柱状动能图表视图。
// MARK: - 3. UI 视图

/// 小尺寸 (`.systemSmall`) 柱状动能图表视图。
struct MomentumChartWidgetView: View {
    var entry: MomentumChartEntry
    
    var maxDuration: Double {
        max(entry.weekDurations.max() ?? 1.0, 1.0)
    }
    
    var body: some View {
        VStack { // 纯净的容器，不加任何自定义 padding
            // ================= 顶部：数据摘要 =================
            HStack {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(entry.weekTotalHours)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text("小时")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(alignment: .firstTextBaseline) {
                    Text("\(entry.weeklyDays)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.orange)
                    Text("天")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            
            // 充当弹簧，自然推开顶部文字和底部图表
            Spacer(minLength: 8)
            
            // ================= 底部：动能柱状图 =================
            ZStack {
                // ✨ 优化点 3：优雅的空状态提示
                if entry.weekTotalHours == 0 && entry.weeklyDays == 0 {
                    Text("本周还未开始\n去书房逛逛吧")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                } else {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(0..<7, id: \.self) { index in
                            let isToday = index == 6
                            let duration = entry.weekDurations[index]
                            let heightRatio = duration / maxDuration
                            
                            GeometryReader { geo in
                                VStack(spacing: 0) {
                                    Spacer(minLength: 0)
                                    
                                    Capsule()
                                        .fill(isToday ? Color.orange.gradient : Color.primary.opacity(0.15).gradient)
                                        .frame(height: max(geo.size.height * CGFloat(heightRatio), 4))
                                }
                            }
                        }
                    }
                }
            }
        }
        // 完全依赖系统的小组件安全区和边距体系
        .containerBackground(Color.adaptiveWidgetBackground, for: .widget)
    }
}

// MARK: - 4. 组件注册入口

/// 小号动能趋势小组件注册配置。
struct MomentumChartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MomentumChartWidget", provider: MomentumChartProvider()) { entry in
            MomentumChartWidgetView(entry: entry)
        }
        .configurationDisplayName("动能趋势")
        .description("过去 7 天的阅读时长动能一览。")
        .supportedFamilies([.systemSmall])
    }
}

#Preview("动能趋势", as: .systemSmall) {
    MomentumChartWidget()
} timeline: {
    MomentumChartEntry(date: Date(), weekDurations: [1.2, 0.5, 2.0, 0.0, 1.5, 3.1, 0.8], weekTotalHours: 12, weeklyDays: 5)
}
