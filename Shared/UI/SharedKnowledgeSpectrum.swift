#if os(macOS) || os(iOS)
import SwiftUI

// MARK: - 知识基因图谱（共享）

/// 全宽光谱彩带 + 底部图例，内部元素自适应撑满空间，无固定尺寸。
/// 调用方通过 `.frame()` 控制最终宽高。
struct SharedKnowledgeSpectrum: View {
    let dataPoints: [SpectrumDataPoint]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                HStack {
                    Text("知识基因")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chart.pie.fill")
                        .foregroundColor(.purple)
                }

                if dataPoints.isEmpty {
                    Text("尚无数据")
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(spacing: AppSpacing.xl) {
                        GeometryReader { geo in
                            let spacing: CGFloat = 4
                            let gapsCount = CGFloat(max(0, dataPoints.count - 1))
                            let availableWidth = max(0, geo.size.width - (spacing * gapsCount))

                            HStack(spacing: spacing) {
                                ForEach(dataPoints) { point in
                                    Rectangle()
                                        .fill(point.color.gradient)
                                        .frame(width: availableWidth * (point.percentage / 100.0))
                                }
                            }
                            .clipShape(Capsule())
                        }
                        .frame(height: 18)

                        HStack(spacing: 40) {
                            ForEach(dataPoints) { point in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(point.color)
                                        .frame(width: 10, height: 10)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(point.tagName)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(.primary)
                                        Text("\(Int(point.percentage))%")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
            }
        }
    }
}

#if DEBUG
#Preview("知识基因 · 有数据") {
    SharedKnowledgeSpectrum(dataPoints: [
        SpectrumDataPoint(tagName: "科幻", percentage: 35, color: .blue),
        SpectrumDataPoint(tagName: "文学", percentage: 25, color: .orange),
        SpectrumDataPoint(tagName: "哲学", percentage: 20, color: .green),
        SpectrumDataPoint(tagName: "历史", percentage: 12, color: .red),
        SpectrumDataPoint(tagName: "科技", percentage: 8, color: .purple),
    ])
    .frame(height: 150)
    .padding()
}
#endif
#endif
