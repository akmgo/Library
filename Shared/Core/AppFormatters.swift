import Foundation

/// ⏱️ 高性能日期与数据格式化引擎
enum AppFormatters {
    /// 中文完整日期格式 (如：2026年4月24日)
    /// 用途：详情页日期、阅读记录等需要明确中文展示的场景
    static let chineseFullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
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
    static let dotShortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        return formatter
    }()

}
