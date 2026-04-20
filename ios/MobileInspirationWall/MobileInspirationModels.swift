#if os(iOS)
import Foundation

// MARK: - 🎨 灵感画廊状态枚举与数据模型

/// 控制灵感画廊内容类型的过滤筛选器。
enum MobileInspirationType: String, CaseIterable {
    case all = "全部"
    case excerpt = "摘录"
    case note = "笔记"
}

/// 控制灵感画廊整体视觉排版模式的开关。
enum MobileInspirationSort: String, CaseIterable {
    /// 严谨模式：按书籍将碎片进行分块排列。
    case byBook = "书籍分类"
    /// 随性模式：打破书籍边界，将碎片混排为瀑布流。
    case random = "随机漫游"
}

/// 聚合摘录 (`Excerpt`) 与笔记 (`Note`) 的统一抽象结构体。
///
/// **设计理念：**
/// 这是解耦 SwiftData 实体与 UI 渲染的关键 DTO (数据传输对象)。
/// 它将原本两张不同的表抹平差异，并挂载了源书籍的书名和封面，供后续的高性能混合列表或瀑布流无缝调度。
struct MobileInspirationSnippet: Identifiable, Hashable {
    let id = UUID()
    let content: String
    let date: Date
    let bookTitle: String
    
    /// 区分该项内容是自我感悟 (true) 还是书本原文 (false)。
    let isNote: Bool
    
    /// 获取其归属书籍的封面，用于在卡片右下角提供溯源指示。
    let coverData: Data?
}
#endif
