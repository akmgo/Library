import Foundation

/// 📡 全局系统通知总线
extension Notification.Name {

    /// 唤起全局“添加书籍”弹窗
    /// 发布者：全局快捷键 ⌘+N 或各个空状态视图
    static let showAddBookModal = Notification.Name("App.ShowAddBookModal")
    
    /// 触发满屏庆祝彩蛋
    /// 发布者：将书籍状态切换为“已读”时
    static let triggerConfetti = Notification.Name("App.TriggerConfetti")
}
