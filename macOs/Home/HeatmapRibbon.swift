#if os(macOS)
import SwiftUI

// MARK: - 🎨 年度无界热力带 (展示型木偶组件)

struct HeatmapRibbon: View {
    let columns: [[HeatmapDataPoint]]
    let activeDays: Int
    
    var body: some View {
        let isEmpty = activeDays == 0
        
        VStack(alignment: .leading, spacing: 16) {
            // ================= 1. 头部标题与统计 =================
            HStack(alignment: .bottom) {
                Text("365 DAYS JOURNEY")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(isEmpty ? .secondary.opacity(0.4) : .secondary)
                    .tracking(2)
                
                Spacer()
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(activeDays)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(isEmpty ? .secondary.opacity(0.3) : .primary)
                    Text("Days")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(isEmpty ? .secondary.opacity(0.3) : .secondary)
                }
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
#endif
