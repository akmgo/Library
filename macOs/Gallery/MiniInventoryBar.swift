#if os(macOS)

import SwiftUI
import SwiftData

// MARK: - 迷你库存堆叠条

/// 用于画廊 Header 右侧展示当前全库书籍分布状况的精美微缩组件。
///
/// 它会在上方列出核心分类的数据标签，并在下方绘制一根高度仅为 6pt 的彩色断带条形图，
/// 使得整个书库的完成度比例一目了然。
struct MiniInventoryBar: View {
    /// 触发重算的完整书库源数据
    let books: [Book]
    
    /// 执行内部过滤的核心计算属性。
    ///
    /// 它通过 `for` 循环互斥地将所有书籍分类到已读、在读、未读和心愿四类中，
    /// 并过滤掉数量为 0 的项目，最后组装出用于驱动 UI 的结构化元组。
    ///
    /// - Returns: 包含总数 (`total`) 与 分段统计清单 (`stats`) 的聚合对象。
    private var inventoryData: (total: Int, stats: [(label: String, count: Int, color: Color)]) {
        var finished = 0
        var reading = 0
        var want = 0
        var unread = 0
        
        // 互斥排他逻辑
        for book in books {
            if book.status == .finished {
                finished += 1
            } else if book.status == .reading {
                reading += 1
            } else if book.isWantToRead {
                want += 1
            } else {
                unread += 1
            }
        }
        
        // 过滤掉数量为 0 的项目
        let filteredStats: [(label: String, count: Int, color: Color)] = [
            ("已读", finished, .indigo),
            ("在读", reading, .blue),
            ("未读", unread, .gray),
            ("心愿", want, .orange)
        ].filter { $0.count > 0 }
        
        let totalCount = filteredStats.reduce(0) { $0 + $1.count }
        
        return (totalCount, filteredStats)
    }
    
    var body: some View {
        // 在 body 顶部安全地提取算好的数据
        let total = inventoryData.total
        let stats = inventoryData.stats
        
        VStack(alignment: .trailing, spacing: 8) { // 整体靠右对齐
            // 上方：极简的标签与数字
            HStack(spacing: 12) {
                if total == 0 {
                    Text("书库为空")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(stats, id: \.label) { stat in
                        HStack(spacing: 4) {
                            Circle().fill(stat.color).frame(width: 6, height: 6)
                            Text("\(stat.count)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(stat.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // 下方：堆叠条形图
            GeometryReader { geo in
                HStack(spacing: 2) { // 间距 2pt，极其锋利
                    if total == 0 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .cornerRadius(3)
                    } else {
                        ForEach(stats, id: \.label) { stat in
                            // 根据准确的比例计算每一截的宽度
                            let width = max(0, (CGFloat(stat.count) / CGFloat(total)) * geo.size.width - 2)
                            Rectangle()
                                .fill(stat.color.opacity(0.8))
                                .frame(width: width)
                                .cornerRadius(3)
                        }
                    }
                }
            }
            .frame(height: 6) // 高度只有 6pt，极度克制
        }
    }
}
#endif
