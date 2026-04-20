#if os(iOS)
import SwiftUI
import SwiftData

// MARK: - 🗓️ 年度热力矩阵

/// 完美复刻 GitHub 贡献度的 iOS 端横滑年度阅读热力图。
///
/// **渲染与调度：**
/// 将全库的所有阅读记录 (`ReadingRecord`) 降维并聚合到 52 周的二维矩阵中。
/// 默认情况下，内部的 `ScrollView` 会通过 `defaultScrollAnchor(.trailing)` 自动将滚动条吸附到最右侧的“今天”。
struct MobileYearlyHeatmapCard: View {
    let allRecords: [ReadingRecord]
    
    @State private var heatmapColumns: [HeatmapColumn] = []
    
    struct HeatmapColumn: Identifiable { let id: Int; let days: [HeatmapDay] }
    struct HeatmapDay: Identifiable { let id = UUID(); let intensity: Double; let isFuture: Bool }
    
    var body: some View {
        GroupBox {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(heatmapColumns) { column in
                        VStack(spacing: 4) {
                            ForEach(column.days) { day in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(
                                        day.isFuture
                                        ? Color.clear
                                        : (day.intensity > 0 ? Color.indigo.opacity(day.intensity) : Color.secondary.opacity(0.15))
                                    )
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                }
                .padding(.top, 12)
            }
            // 自动滚动到最右边（最近日期）
            .defaultScrollAnchor(.trailing)
        } label: {
            HStack {
                Text("打卡密度")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundColor(.indigo)
            }
        }
        .onAppear { processHeatmapData() }
        .onChange(of: allRecords) { _, _ in processHeatmapData() }
    }
    
    // MARK: - 热力矩阵聚合算法
    
    private func processHeatmapData() {
        var cal = Calendar.current; cal.firstWeekday = 2; let today = cal.startOfDay(for: Date())
        var dailyDurations: [Date: TimeInterval] = [:]
        for record in allRecords {
            dailyDurations[cal.startOfDay(for: record.date ?? Date()), default: 0] += record.readingDuration
        }
        
        let daysToSubtract = (cal.component(.weekday, from: today) + 5) % 7
        let currentWeekStart = cal.date(byAdding: .day, value: -daysToSubtract, to: today)!
        let startDate = cal.date(byAdding: .weekOfYear, value: -51, to: currentWeekStart)! // 获取完整的 52 周
        
        var cols: [HeatmapColumn] = []
        for weekOffset in 0..<52 {
            var daysInWeek: [HeatmapDay] = []
            for dayOffset in 0..<7 {
                let date = cal.date(byAdding: .day, value: weekOffset * 7 + dayOffset, to: startDate)!
                let duration = dailyDurations[date] ?? 0
                let isFuture = date > today
                let intensity = isFuture ? 0 : (duration > 0 ? min((duration / 3600.0) * 0.7 + 0.3, 1.0) : 0)
                daysInWeek.append(HeatmapDay(intensity: intensity, isFuture: isFuture))
            }
            cols.append(HeatmapColumn(id: weekOffset, days: daysInWeek))
        }
        heatmapColumns = cols
    }
}
#endif
