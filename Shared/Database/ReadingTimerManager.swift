import Foundation
import SwiftData
import WidgetKit
import SwiftUI
internal import Combine

/// 全局阅读焦点计时状态机。
///
/// **核心职责：**
/// 该类充当主 App 和锁屏小组件 (Widget/Live Activity) 之间的状态粘合剂。
/// 它不依赖实时的高频心跳，而是将 `startTime` 等绝对状态写入系统级 `UserDefaults (AppGroup)` 中。
/// 当收到开始或结束指令时，它会唤起 WidgetCenter 刷新外部 UI，或将累计时间持久化。
@MainActor
class ReadingTimerManager: ObservableObject {
    static let shared = ReadingTimerManager()
    
    // 直接实例化 UserDefaults，杜绝任何访问控制权限报错
    private let defaults = UserDefaults(suiteName: "group.com.akram.library") ?? UserDefaults.standard
    
    /// 指示焦点模式是否正在进行的响应式状态。
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentBookTitle: String = ""
    
    /// 当次焦点阅读的启动原子钟基准点。
    @Published var startTime: Date = Date()
    
    /// 从外部持久化沙盒中还原应用启动前的倒计时状态。
    private init() {
        self.isRunning = defaults.bool(forKey: "local_timer_isRunning")
        self.currentBookTitle = defaults.string(forKey: "local_timer_bookTitle") ?? ""
        let timestamp = defaults.double(forKey: "local_timer_startTime")
        if timestamp > 0 { self.startTime = Date(timeIntervalSince1970: timestamp) }
    }
    
    /// 从共享组配置中心同步并对齐当前的开关与暂停状态。
    func syncStateFromRemote() {
        self.isRunning = defaults.bool(forKey: "local_timer_isRunning")
        self.isPaused = defaults.bool(forKey: "is_timer_paused")
    }
    
    /// 全局触发计时器启动动作。
    ///
    /// 此方法会将当前时间和焦点书名下发至沙盒共享存储中，并唤起外层 `WidgetCenter` 进行卡片刷新。
    ///
    /// - Parameter bookTitle: 当前将要聚焦阅读的书籍标题。
    func startReading(bookTitle: String) {
        self.isRunning = true
        self.currentBookTitle = bookTitle
        self.startTime = Date()
        
        defaults.set(true, forKey: "local_timer_isRunning")
        defaults.set(bookTitle, forKey: "local_timer_bookTitle")
        defaults.set(self.startTime.timeIntervalSince1970, forKey: "local_timer_startTime")
        
        // 呼叫小组件立刻刷新
        WidgetCenter.shared.reloadTimelines(ofKind: "ReadingTimerWidget")
    }
    
    /// 全局触发计时器终止，并执行数据合并计算。
    ///
    /// 这是一个关键的业务收口操作。它会使用原子钟时间求差法，避免掉帧导致的误差。
    /// 如果单次阅读时间大于 1 分钟，引擎将自动查询该书籍在 **当日** 是否已有 `ReadingRecord`，
    /// 并在其基础上实行时长累加合并操作，确保按日维度聚合的高数据纯净度。
    ///
    /// - Parameters:
    ///   - context: 准备写入的数据库运行环境。
    ///   - book: 绑定这笔阅读时间投入的核心书籍对象。
    func stopReading(context: ModelContext, book: Book) {
        guard isRunning else { return }
        let duration = Date().timeIntervalSince(startTime) // 获得秒数
        
        // 1. 清理本机状态与 UI
        self.isRunning = false
        defaults.set(false, forKey: "local_timer_isRunning")
        WidgetCenter.shared.reloadTimelines(ofKind: "ReadingTimerWidget")
        
        // 2. 数据合并逻辑：同一天、同一本书，直接累加
        if duration >= 60 { // 大于 1 分钟才算有效阅读
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            
            let existingRecord = book.readingRecords?.first { record in
                guard let recordDate = record.date else { return false }
                return cal.isDate(recordDate, inSameDayAs: today)
            }
            
            if let record = existingRecord {
                record.readingDuration += duration
            } else {
                let newRecord = ReadingRecord(date: Date(), readingDuration: duration, book: book)
                context.insert(newRecord)
                if book.readingRecords == nil { book.readingRecords = [] }
                book.readingRecords?.append(newRecord)
            }
            try? context.save()
            WidgetCenter.shared.reloadTimelines(ofKind: "DesktopDashboardWidget")
        }
    }
}
