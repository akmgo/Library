import Foundation
import SwiftUI


/// 专供动能图表渲染使用的数据点
struct MomentumDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Double
    let isToday: Bool
}

/// 专供“年度热力矩阵”渲染使用的单个单元格数据模型
struct HeatmapDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    /// 当天阅读分钟数，供移动端和无 tooltip 场景直接渲染。
    let minutes: Int
    /// 颜色深浅的透明度值 (0.0 到 1.0)
    let intensity: Double
    /// 是否是未来的日期（用于隐藏圆点）
    let isFuture: Bool
    /// 鼠标悬停时的提示文字
    let tooltip: String
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
