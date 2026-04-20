#if os(macOS)
import Foundation

// MARK: - 灵感画廊枚举与结构定义

/// 灵感画廊中可选的内容筛选维度。
enum InspirationContentType: String, CaseIterable {
    case all = "全部"
    case excerpt = "摘录"
    case note = "笔记"
}

/// 灵感画廊中可选的排版漫游模式。
enum InspirationSortMode: String, CaseIterable {
    /// 严谨的档案室视图：按照书籍进行归类分组，呈现长列表。
    case byBook = "书籍分类"
    /// 随性的灵感视图：打破书籍边界，采用多列错落的瀑布流 (Masonry) 乱序排列。
    case random = "随机漫游"
}

/// 聚合摘录 (`Excerpt`) 与笔记 (`Note`) 的统一抽象结构体。
///
/// **设计逻辑：**
/// 由于 SwiftData 原生的 `Excerpt` 和 `Note` 是不同的表模型，
/// UI 渲染层需要一个统一的数据结构 (DTO) 来抹平它们的差异，从而实现混合列表渲染与打乱。
struct InspirationSnippet: Identifiable, Hashable {
    /// UI 渲染层唯一标识符
    let id = UUID()
    
    /// 纯文本内容（划线的原句，或用户的感悟）
    let content: String
    /// 创建的时间戳
    let date: Date
    /// 该记录归属的书籍名称
    let bookTitle: String
    /// 标识该记录是一条思考笔记 (true) 还是原著摘录 (false)
    let isNote: Bool
    /// 用于渲染视觉缩略图的封面二进制数据
    let coverData: Data?
}
#endif
