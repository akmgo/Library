import Foundation

/// 📡 全局系统通知总线
extension Notification.Name {

    /// 唤起全局“添加书籍”弹窗
    /// 发布者：全局快捷键 ⌘+N 或各个空状态视图
    static let showAddBookModal = Notification.Name("App.ShowAddBookModal")

    /// 唤起全局搜索
    /// 发布者：iOS 主页下拉、外接键盘快捷键或未来的全局入口。
    static let showGlobalSearch = Notification.Name("App.ShowGlobalSearch")
}
