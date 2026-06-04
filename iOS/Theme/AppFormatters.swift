import Foundation

enum AppDateText {
    private static let zhCN = Locale(identifier: "zh_Hans_CN")
    static let chineseLocale = Locale(identifier: "zh_Hans_CN")

    private static let monthDayFormatter = formatter("M月d日")
    private static let fullDateFormatter = formatter("yyyy年M月d日")
    private static let monthFormatter = formatter("M月")
    private static let monthTitleFormatter = formatter("LLLL")
    private static let timeFormatter = formatter("HH:mm")

    static func monthDay(_ date: Date) -> String {
        monthDayFormatter.string(from: date)
    }

    static func fullDate(_ date: Date) -> String {
        fullDateFormatter.string(from: date)
    }

    static func month(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }

    static func monthTitle(_ date: Date) -> String {
        monthTitleFormatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = zhCN
        formatter.dateFormat = format
        return formatter
    }
}
