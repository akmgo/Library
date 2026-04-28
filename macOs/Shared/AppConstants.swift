import SwiftUI

/// 🎯 全局常量与文案字典
enum AppConstants {
    // MARK: - 📚 评价系统文案 (索引 0-7)

    static let ratingPoeticTexts: [String] = [
        "静待沉淀", // 0
        "浮光掠影", // 1
        "浅尝辄止", // 2
        "开卷有益", // 3
        "引人入胜", // 4
        "回味无穷", // 5
        "醍醐灌顶", // 6
        "灵魂共振" // 7
    ]

    /// ✨ 新增：全局统一的三重推荐度数据解包器
    static func recommendationData(for rating: Int) -> (icon: String, text: String, color: Color)? {
        switch rating {
        case 1...3: return ("leaf.fill", "浅尝辄止", .teal)
        case 4...5: return ("star.fill", "引人入胜", .orange)
        case 6...7: return ("flame.fill", "强烈推荐", .red)
        default: return nil
        }
    }

    // MARK: - 🏷️ 书籍状态映射表

    /// 假设 BookStatus 是你已有的枚举
    static let statusOptions: [(BookStatus, String)] = [
        (.unread, "待读"),
        (.reading, "在读"),
        (.finished, "已读"),
        (.abandoned, "弃读"),
        (.wantToRead, "想读")
    ]

    // MARK: - 🏷️ 预设标签库

    static let predefinedTags: [String] = [
        "哲学", "历史", "人文", "经典", "社会", "政治", "经济", "法律",
        "心理", "思考", "成长", "管理", "商业", "投资", "技术", "文学",
        "传记", "艺术", "宗教", "科普", "编程", "玄幻"
    ]

    // MARK: - 📐 全局 UI 规范常量 (可选补充)

    enum UI {
        static let defaultCornerRadius: CGFloat = 16.0
        static let standardIconSize: CGFloat = 16.0
    }
}
