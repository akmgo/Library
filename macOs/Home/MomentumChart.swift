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

        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("双周动能")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                }

                ZStack {
                    Chart(dataPoints) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Minutes", isEmpty ? 1 : item.minutes)
                        )
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
                    .frame(height: 80)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}


#endif
