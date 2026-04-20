#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - 🎨 年度无界热力带

/// 全屏宽度延展的全年 Github 风活跃热力矩阵。
///
/// **渲染与聚合引擎：**
/// 严格按照 53 个星期，每周 7 天构建矩阵空间。
/// 根据当天的总专注时长，动态决定热力圆点的颜色深度 (Opacity)。
struct FluidHeatmapRibbon: View {
    let allRecords: [ReadingRecord]
    @State private var heatmapColumns: [[(Date, Double, Bool, String)]] = []
    @State private var activeDaysThisYear: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                Text("365 DAYS JOURNEY").font(.system(size: 12, weight: .black, design: .rounded)).foregroundColor(.secondary).tracking(2)
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(activeDaysThisYear)").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                    Text("Days").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 4) {
                ForEach(0..<heatmapColumns.count, id: \.self) { c in
                    VStack(spacing: 4) {
                        ForEach(0..<heatmapColumns[c].count, id: \.self) { r in
                            let cell = heatmapColumns[c][r]
                            Circle().fill(cell.2 ? Color.clear : (cell.1 > 0 ? Color.indigo.opacity(cell.1) : Color.secondary.opacity(0.12))).aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity).help(cell.3)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { process() }.onChange(of: allRecords) { _, _ in process() }
    }
    
    private func process() {
        var cal = Calendar.current; cal.firstWeekday = 2; let today = cal.startOfDay(for: Date())
        var durs: [Date: TimeInterval] = [:]; var activeDays = 0
        for r in allRecords { durs[cal.startOfDay(for: r.date ?? Date.distantPast), default: 0] += r.readingDuration }
        
        let daysToSubtract = (cal.component(.weekday, from: today) + 5) % 7
        let currentWeekStart = cal.date(byAdding: .day, value: -daysToSubtract, to: today)!
        let totalWeeks = 53
        let start = cal.date(byAdding: .weekOfYear, value: -(totalWeeks - 1), to: currentWeekStart)!
        
        var cols = [[(Date, Double, Bool, String)]]()
        for w in 0..<totalWeeks {
            var col = [(Date, Double, Bool, String)]()
            for d in 0..<7 {
                let date = cal.date(byAdding: .day, value: w * 7 + d, to: start)!
                let dur = durs[date] ?? 0; let fut = date > today; var int = 0.0
                if !fut, dur > 0 { int = min((dur / 3600.0) * 0.7 + 0.3, 1.0); activeDays += 1 }
                col.append((date, int, fut, fut ? "未到" : (dur == 0 ? "未打卡" : "专注 \(Int(dur / 60)) 分钟")))
            }
            cols.append(col)
        }
        heatmapColumns = cols; activeDaysThisYear = activeDays
    }
}
#endif
