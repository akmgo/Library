#if os(iOS)
import SwiftUI

// MARK: - 🗓️ 年度热力矩阵 (接入视觉引擎版)

struct MobileYearlyHeatmapCard: View {
    let columns: [[HeatmapDataPoint]]
    let activeDays: Int

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack {
                    Text("打卡密度")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    AppCapsuleLabel(
                        text: "\(activeDays)天",
                        tint: .indigo,
                        fontSize: 13,
                        horizontalPadding: 6,
                        verticalPadding: 2,
                        fillOpacity: 0.10
                    )
                    Spacer()
                    Image(systemName: "square.grid.3x3.fill")
                        .foregroundColor(.indigo)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xxs) {
                        ForEach(0..<columns.count, id: \.self) { colIndex in
                            let column = columns[colIndex]
                            VStack(spacing: AppSpacing.xxs) {
                                ForEach(column, id: \.id) { day in
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(
                                            day.isFuture
                                            ? Color.clear
                                            : (day.minutes > 0 ? Color.indigo.opacity(day.intensity) : Color.secondary.opacity(0.15))
                                        )
                                        .frame(width: 12, height: 12)
                                }
                            }
                        }
                    }
                    .padding(.top, AppSpacing.s)
                }
                .defaultScrollAnchor(.trailing)
            }
        }
    }
}

#if DEBUG
private struct PreviewHeatmapCard: View {
    var body: some View {
        let columns = (0..<53).map { _ in
            (0..<7).map { _ in
                HeatmapDataPoint(
                    date: Date(),
                    minutes: Int.random(in: 0...180),
                    intensity: .random(in: 0...1),
                    isFuture: false,
                    tooltip: ""
                )
            }
        }
        MobileYearlyHeatmapCard(columns: columns, activeDays: 89)
            .padding()
            .background(AppColors.primaryBackground(for: .light))
    }
}

#Preview("年度热力图卡") {
    PreviewHeatmapCard()
}
#endif


#endif
