import Foundation

/// ⏱️ 高性能日期与数据格式化引擎
enum AppFormatters {
    // MARK: - 📅 日期格式化器
    
    /// 标准数字日期格式 (如：2026-04-24 或本地化等效格式)
    /// 用途：书籍详情页的高级日期选择器显示
    static let numericDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // ✨ 修复报错：改为合法的 DateFormatter.Style
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// 中文短日期格式 (如：4月24日)
    /// 用途：年度轨迹 (YearlyTimelineView) 的时间轴节点
    static let chineseShortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()
    
    /// 极简小数点日期格式 (如：04.24)
    /// 用途：卡片上的“历时胶囊 (TimelineJourneyTicket)”起点与终点
    static let dotShortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        return formatter
    }()
    
    /// 斜杠短日期格式 (如：26/04/24)
    /// 用途：画廊卡片底部统计
    static let slashDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yy/MM/dd"
        return formatter
    }()
}
