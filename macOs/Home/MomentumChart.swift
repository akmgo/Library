#if os(macOS)
import Charts
import SwiftUI

// MARK: - 📈 无界动能柱状图 (智能空状态版)

struct MomentumChart: View {
    let dataPoints: [MomentumDataPoint]
    let totalMinutes: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let isEmpty = totalMinutes == 0
        
        VStack(alignment: .leading, spacing: 16) {
            // ================= 1. 顶部数据头 =================
            HStack {
                Text("双周动能")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()

                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
            }
            
            // ================= 2. 图表渲染区 =================
            ZStack {
                // 底层图表引擎
                Chart(dataPoints) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        // 如果是空状态，给一个微小的假数据(如 1)来撑起底座槽，否则真实渲染
                        y: .value("Minutes", isEmpty ? 1 : item.minutes)
                    )
                    // 空状态下渲染虚化的骨架槽，真实状态下渲染渐变蓝
                    .foregroundStyle(isEmpty
                                     ? Color.secondary.opacity(0.05).gradient
                                     : (item.isToday ? Color.blue.gradient : Color.secondary.opacity(0.15).gradient))
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(preset: .aligned, values: .stride(by: .day, count: 2)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.day())
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary.opacity(isEmpty ? 0.3 : 0.6))
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                // 极度压低的高度，营造声波感
                .frame(height: 80)
                
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }
}


#endif
