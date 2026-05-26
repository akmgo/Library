#if os(macOS)
import SwiftUI

// MARK: - 迷你库存堆叠条 (展示型木偶组件)

/// 用于展示数据分布状况的精美微缩组件。
/// 完全解耦：不依赖任何数据库模型，仅通过纯数据点驱动。
struct MiniInventoryBar: View {
    /// 顶部显示的书库总数
    let totalCount: Int
    /// 已经计算好颜色、数量和百分比的纯数据点
    let dataPoints: [InventoryDataPoint]
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // ================= 1. 上方标签与数字 =================
            HStack(spacing: 12) {
                if totalCount == 0 {
                    Text("书库为空")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(dataPoints) { point in
                        HStack(spacing: 4) {
                            Circle().fill(point.color).frame(width: 6, height: 6)
                            Text("\(point.count)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(point.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // ================= 2. 下方堆叠条形图 =================
            GeometryReader { geo in
                // 缝隙宽度设定为 2pt
                let spacing: CGFloat = 2
                
                // ✨ 严谨的数学几何计算：算出共有几个间隙，并扣除它们，得到纯粹的"净可用宽度"
                let gapsCount = CGFloat(max(0, dataPoints.count - 1))
                let availableWidth = max(0, geo.size.width - (spacing * gapsCount))
                
                HStack(spacing: spacing) {
                    if totalCount == 0 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .cornerRadius(3)
                    } else {
                        ForEach(dataPoints) { point in
                            Rectangle()
                                .fill(point.color.opacity(0.8))
                                // 使用净宽度乘以绝对百分比，严丝合缝，绝不溢出！
                                .frame(width: max(0, availableWidth * point.percentage))
                                .cornerRadius(3)
                        }
                    }
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - 👁️ 预览
#Preview("迷你库存条 (组件)") {
    // 在预览里直接手写一份干净的假数据塞进去，连 PreviewData.shared 都不需要了！
    let mockData = [
        InventoryDataPoint(label: "已读", count: 42, color: .indigo, percentage: 0.42),
        InventoryDataPoint(label: "在读", count: 18, color: .blue, percentage: 0.18),
        InventoryDataPoint(label: "想读", count: 30, color: .orange, percentage: 0.30),
        InventoryDataPoint(label: "未读", count: 10, color: .gray, percentage: 0.10)
    ]
    
    MiniInventoryBar(totalCount: 100, dataPoints: mockData)
        .frame(width: 320)
        .padding(40)
}
#endif
