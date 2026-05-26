#if os(macOS)
import SwiftUI

// MARK: - 🎨 年度无界热力带 (展示型木偶组件)

struct HeatmapRibbon: View {
    let columns: [[HeatmapDataPoint]]
    let activeDays: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
            // ================= 1. 头部标题与统计 =================
            HStack {
                Text("年度热力图")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()

                Image(systemName: "square.grid.3x3.fill")
                    .foregroundColor(.indigo)
            }
            
            // ================= 2. 矩阵渲染区域 =================
            ZStack {
                HStack(spacing: 4) {
                    ForEach(0..<columns.count, id: \.self) { c in
                        VStack(spacing: 4) {
                            ForEach(columns[c]) { cell in
                                Circle()
                                    // 逻辑极度清晰：未来透明，有数据用深度靛蓝，没数据用极浅灰色
                                    .fill(cell.isFuture ? Color.clear : (cell.intensity > 0 ? Color.indigo.opacity(cell.intensity) : Color.secondary.opacity(0.12)))
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .help(cell.tooltip) // macOS 原生的悬停提示框
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        }
    }
}
#endif
