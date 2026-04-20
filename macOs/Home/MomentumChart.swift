#if os(macOS)
import SwiftUI
import SwiftData
import Charts

// MARK: - 📈 无界动能柱状图

/// 使用 Swift Charts 渲染的“双周动能带”。
///
/// **渲染特性：**
/// 该图表不包裹在 `GroupBox` 内，而是直接贴附于主背景。
/// 通过隐藏 Y 轴、极限压低图表高度，并使用 `.day` 跨度合并绘制，
/// 呈现出类似心脏声波图的灵动长方形柱阵。
struct FluidMomentumChart: View {
    let allRecords: [ReadingRecord]
    @State private var chartData: [(Date, Double, Bool)] = []
    @State private var totalMinutes: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                Text("14 DAYS MOMENTUM").font(.system(size: 12, weight: .black, design: .rounded)).foregroundColor(.secondary).tracking(2)
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(totalMinutes)").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                    Text("Min").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.secondary)
                }
            }
            
            Chart(chartData, id: \.0) { item in
                BarMark(x: .value("Date", item.0, unit: .day), y: .value("Minutes", item.1))
                .foregroundStyle(item.2 ? Color.blue.gradient : Color.secondary.opacity(0.15).gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(preset: .aligned, values: .stride(by: .day, count: 2)) { value in
                    if let date = value.as(Date.self) { AxisValueLabel { Text(date, format: .dateTime.day()).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundColor(.secondary.opacity(0.6)) } }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 80).frame(maxWidth: .infinity)
        }
        .onAppear { process() }.onChange(of: allRecords) { _, _ in process() }
    }
    
    private func process() {
        let cal = Calendar.current; let today = cal.startOfDay(for: Date())
        var temp = [(Date, Double, Bool)](); var total = 0.0
        for i in (0..<14).reversed() { temp.append((cal.date(byAdding: .day, value: -i, to: today)!, 0, i == 0)) }
        for r in allRecords {
            let d = cal.startOfDay(for: r.date ?? Date.distantPast)
            if let a = cal.dateComponents([.day], from: d, to: today).day, a >= 0, a < 14 {
                let mins = r.readingDuration / 60.0; temp[13 - a].1 += mins; total += mins
            }
        }
        chartData = temp; totalMinutes = Int(total)
    }
}
#endif
