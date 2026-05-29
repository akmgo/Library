#if os(macOS) || os(iOS)
import Charts
import SwiftUI

// MARK: - 双周动能（共享）

/// 内容自适应柱状图，无固定尺寸。
/// 调用方通过 `.frame()` 控制最终宽高。
/// 今日柱使用主色 `readingAmber`，其余天为浅色版本。
struct SharedMomentumChart: View {
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
                        .foregroundColor(AppColors.readingAmber)
                }

                if isEmpty {
                    Text("暂无阅读数据")
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ZStack {
                        Chart(dataPoints) { item in
                            BarMark(
                                x: .value("Date", item.date, unit: .day),
                                y: .value("Minutes", item.minutes)
                            )
                            .foregroundStyle(item.isToday ? AppColors.readingAmber.gradient : AppColors.readingAmber.opacity(0.25).gradient)
                            .cornerRadius(4)
                        }
                        .chartXAxis {
                            AxisMarks(preset: .aligned, values: .stride(by: .day, count: 2)) { value in
                                if let date = value.as(Date.self) {
                                    AxisValueLabel {
                                        Text(date, format: .dateTime.day())
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                }
                            }
                        }
                        .chartYAxis(.hidden)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#if DEBUG
#Preview("动能 · 有数据") {
    SharedMomentumChart(
        dataPoints: (0..<14).map { i in
            MomentumDataPoint(date: Calendar.current.date(byAdding: .day, value: -13 + i, to: Date()) ?? Date(),
                              minutes: Double(Int.random(in: 0...45)), isToday: i == 13)
        },
        totalMinutes: 320
    )
    .frame(height: 200)
    .padding()
}

#Preview("动能 · 空状态") {
    SharedMomentumChart(dataPoints: [], totalMinutes: 0)
        .frame(height: 200)
        .padding()
}
#endif
#endif
