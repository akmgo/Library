#if os(iOS)
import SwiftUI

// MARK: - 🧠 知识基因图谱 (纯粹渲染版)

struct MobileKnowledgeSpectrumCard: View {
    let dataPoints: [SpectrumDataPoint]

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack {
                    Text("知识基因")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chart.pie.fill")
                        .foregroundColor(.purple)
                }
                if dataPoints.isEmpty {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("缺乏数据")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    VStack(spacing: AppSpacing.xl) {
                        GeometryReader { geo in
                            let spacing: CGFloat = 4
                            let gapsCount = CGFloat(max(0, dataPoints.count - 1))
                            let availableWidth = max(0, geo.size.width - (spacing * gapsCount))
                            HStack(spacing: spacing) {
                                ForEach(dataPoints, id: \.tagName) { point in
                                    Rectangle()
                                        .fill(point.color.gradient)
                                        .frame(width: availableWidth * (point.percentage / 100.0))
                                }
                            }
                            .clipShape(Capsule())
                        }
                        .frame(height: 16)
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(dataPoints, id: \.tagName) { point in
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(point.color)
                                        .frame(width: 10, height: 10)
                                    VStack(spacing: 2) {
                                        Text(point.tagName)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text("\(Int(point.percentage))%")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .padding(.top, AppSpacing.xs)
        }
    }
}

#if DEBUG
#Preview("知识基因卡") {
    let points = [
        SpectrumDataPoint(tagName: "科幻", percentage: 0.35, color: .blue),
        SpectrumDataPoint(tagName: "文学", percentage: 0.25, color: .orange),
        SpectrumDataPoint(tagName: "哲学", percentage: 0.20, color: .green),
        SpectrumDataPoint(tagName: "历史", percentage: 0.12, color: .red),
        SpectrumDataPoint(tagName: "科技", percentage: 0.08, color: .purple),
    ]
    return MobileKnowledgeSpectrumCard(dataPoints: points)
        .padding()
        .background(AppColors.primaryBackground(for: .light))
}
#endif


#endif
