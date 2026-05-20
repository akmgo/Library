#if os(iOS)
import SwiftUI

// MARK: - 🗓️ 年度热力矩阵 (接入视觉引擎版)

/// iOS 专属的热力图数据模型，携带真实的分钟数
struct MobileHeatmapDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
    let isFuture: Bool
}

struct MobileYearlyHeatmapCard: View {
    let columns: [[MobileHeatmapDataPoint]]
    let activeDays: Int
    
    var body: some View {
        GroupBox {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(0..<columns.count, id: \.self) { colIndex in
                        let column = columns[colIndex]
                        VStack(spacing: 4) {
                            ForEach(column, id: \.id) { day in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(
                                        day.isFuture
                                        ? Color.clear
                                        : (day.minutes > 0
                                           // ✨ 核心接入：调用全局 VisualEngines 获取标准透明度
                                           ? Color.indigo.opacity(VisualEngines.ReadingHeatmap.intensity(for: day.minutes))
                                           : Color.secondary.opacity(0.15))
                                    )
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                }
                .padding(.top, 12)
            }
            .defaultScrollAnchor(.trailing)
        } label: {
            HStack {
                Text("打卡密度")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(activeDays)天")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.indigo)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.indigo.opacity(0.1))
                    .clipShape(Capsule())
                
                Spacer()
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundColor(.indigo)
            }
        }
    }
}
#endif
