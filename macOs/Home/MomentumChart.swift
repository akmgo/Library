#if os(macOS)
import Charts
import SwiftUI

// MARK: - 📈 无界动能柱状图 (智能空状态版)

struct MomentumChart: View {
    let dataPoints: [MomentumDataPoint]
    let totalMinutes: Int
    
    var body: some View {
        let isEmpty = totalMinutes == 0
        
        VStack(alignment: .leading, spacing: 16) {
            // ================= 1. 顶部数据头 =================
            HStack(alignment: .bottom) {
                Text("14 DAYS MOMENTUM")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(isEmpty ? .secondary.opacity(0.4) : .secondary)
                    .tracking(2)
                
                Spacer()
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(totalMinutes)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(isEmpty ? .secondary.opacity(0.3) : .primary)
                    Text("Min")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(isEmpty ? .secondary.opacity(0.3) : .secondary)
                }
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
    }
}


#endif
