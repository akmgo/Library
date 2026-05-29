import Foundation
import SwiftUI


/// 专供动能图表渲染使用的数据点
struct MomentumDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Double
    let isToday: Bool
}

/// 专供跑马灯使用的纯数据结构
struct ResonanceDataPoint {
    let content: String
    let source: String
}

struct SpectrumDataPoint: Identifiable {
    // 直接用标签名作为唯一标识符
    var id: String { tagName }
    let tagName: String
    let percentage: Double
    let color: Color
}

/// 专供“迷你库存条”渲染使用的纯数据结构
struct InventoryDataPoint: Identifiable {
    // 使用标签名（如"已读"）作为唯一标识
    var id: String { label }
    let label: String
    let count: Int
    let color: Color
    /// 该分类占总数的绝对百分比 (0.0 ~ 1.0)
    let percentage: Double
}
