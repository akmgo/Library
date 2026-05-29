#if os(iOS)
import SwiftUI
import Charts

// MARK: - 📈 动能折线组件 (纯粹渲染版)

struct MobileMomentumChartCard: View {
    let dataPoints: [MomentumDataPoint]
    let totalMinutes: Int

    var totalDays: Int {
        dataPoints.filter { $0.minutes > 0 }.count
    }

    var maxMinutes: Int {
        Int(dataPoints.map { $0.minutes }.max() ?? 0)
    }

    var avgMinutes: Int {
        totalDays > 0 ? (totalMinutes / totalDays) : 0
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack {
                    Text("双周动能")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.blue)
                }
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 0) {
                        MomentumAppStat(title: "阅读天数", value: "\(totalDays)", unit: "天")
                        Spacer(minLength: AppSpacing.xxs + 1)
                        MomentumAppStat(title: "总计时间", value: "\(totalMinutes)", unit: "分")
                        Spacer(minLength: AppSpacing.xxs + 1)
                        MomentumAppStat(title: "单日最高", value: "\(maxMinutes)", unit: "分")
                        Spacer(minLength: AppSpacing.xxs + 1)
                        MomentumAppStat(title: "日均阅读", value: "\(avgMinutes)", unit: "分")
                    }
                    .padding(.bottom, 16)
                    if dataPoints.isEmpty {
                        Text("暂无阅读数据")
                            .font(AppTypography.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
                    } else {
                        Chart(dataPoints, id: \.date) { item in
                            AreaMark(x: .value("Day", item.date), y: .value("Minutes", item.minutes))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(LinearGradient(colors: [Color.blue.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("Day", item.date), y: .value("Minutes", item.minutes))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Color.blue)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        }
                        .chartYAxis(.hidden)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                                AxisValueLabel(format: .dateTime.day())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .frame(height: 70)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

private struct MomentumAppStat: View {
    let title: String; let value: String; let unit: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                Text(unit).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary.opacity(0.8))
            }
        }
    }
}

#if DEBUG
private struct PreviewMomentumCard: View {
    var body: some View {
        let today = Date()
        let points = (0..<14).map { i in
            let date = Calendar.current.date(byAdding: .day, value: -13 + i, to: today)!
            return MomentumDataPoint(
                date: date,
                minutes: Double.random(in: 0...120),
                isToday: Calendar.current.isDate(date, inSameDayAs: today)
            )
        }
        MobileMomentumChartCard(dataPoints: points, totalMinutes: Int(points.reduce(0) { $0 + $1.minutes }))
            .padding()
            .background(AppColors.primaryBackground(for: .light))
    }
}

#Preview("双周动能卡") {
    PreviewMomentumCard()
}
#endif


#endif
