#if os(macOS)
import SwiftUI

// MARK: - 🧠 知识基因图谱

/// 全宽铺开的知识维度光谱彩带。
///
/// 最高排名的 5 个维度将被映射为长度不等、颜色绚丽的光滑胶囊条，呈现用户的宏观知识面分布。
struct KnowledgeSpectrum: View {
    /// 1. 彻底解耦：只接收纯粹的 UI 数据点
    let dataPoints: [SpectrumDataPoint]
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        // ✨ 核心重构：抛弃 GroupBox，换上原生的液态玻璃舱
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            // 头部 Label
            HStack {
                Text("知识基因")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.purple)
            }
            
            if dataPoints.isEmpty {
                // 空状态
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("缺乏数据")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 数据展示状态
                VStack(spacing: AppSpacing.xl) {
                    // 🌈 光谱彩带渲染区
                    GeometryReader { geo in
                        // 1. 定义固定的间距
                        let spacing: CGFloat = 4
                                                
                        // 2. 算出现有元素之间共有几个间隙
                        let gapsCount = CGFloat(max(0, dataPoints.count - 1))
                                                
                        // 3. 计算扣除所有间隙后，真正可以用来画色块的“净可用宽度”
                        let availableWidth = max(0, geo.size.width - (spacing * gapsCount))
                                                
                        HStack(spacing: spacing) {
                            ForEach(dataPoints) { point in
                                Rectangle()
                                    .fill(point.color.gradient)
                                    // 4. 完美按百分比瓜分“净宽度”
                                    .frame(width: availableWidth * (point.percentage / 100.0))
                            }
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 18)
                    
                    // 🏷️ 底部图例标签区
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
        .padding(AppSpacing.xl)
        .background(
            AppColors.secondaryBackground(for: colorScheme).opacity(0.72),
            in: RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
        )
        .glassEffect(in: .rect(cornerRadius: AppRadius.panel))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.panel, style: .continuous)
                .stroke(AppColors.tertiaryBackground(for: colorScheme).opacity(0.9), lineWidth: 1)
        )
    }
}

#endif
