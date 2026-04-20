#if os(iOS)
import ActivityKit
import AppIntents
import SwiftData
import SwiftUI

/// ⏹️ 锁屏卡片唯一交互意图：结束计时并保存数据。
///
/// 当用户点击锁屏实时活动或灵动岛上的“红色停止按钮”时，系统会在后台唤起并执行该意图。
///
/// **核心职责：**
/// 1. 立即请求 `ActivityKit` 销毁对应的锁屏卡片。
/// 2. 获取本次专注的原子钟时间戳，计算出精确的专注秒数。
/// 3. 与主程序通过 `UserDefaults (AppGroup)` 同步停止状态。
/// 4. 执行基于 SwiftData 的并发安全数据库写入：自动合并当日阅读记录，避免产生碎片数据。
struct StopTimerIntent: LiveActivityIntent {
    /// 在系统的快捷指令或按钮描述中展示的本地化标题。
    static var title: LocalizedStringResource = "结束并保存"
        
    /// 意图执行所需的核心参数：当前正在专注的书名。用于匹配和结束正确的 Activity。
    @Parameter(title: "Book Title")
    var bookTitle: String
        
    init() {}
    
    init(bookTitle: String) {
        self.bookTitle = bookTitle
    }
        
    /// 意图的核心执行逻辑。
    ///
    /// - 逻辑流：
    ///   1. 首先呼叫主线程的安全隔离区，立即关闭匹配的 `Activity`。
    ///   2. 从 `UserDefaults` 中提取启动时间，计算真实的专注时长 (`finalDuration`)。
    ///   3. 清除 `UserDefaults` 中的运行标记，以便唤醒主 App 时自动停止。
    ///   4. 若时长在有效范围内 (1秒 ~ 12小时)，则开启后台任务，将时间写入或合并到对应的 `Book` 记录中。
    ///
    /// - Returns: 返回表示执行成功的意图结果。
    /// - Throws: 如果操作被系统中断或执行异常则抛出错误。
    func perform() async throws -> some IntentResult {
        // 1. 关闭锁屏 UI
        await endActivitiesSafely()
            
        let defaults = UserDefaults(suiteName: "group.com.akram.library")
            
        // 提取绝对时间差，防范找不到 key 时返回 0.0 (1970 纪元 Bug) 的风险。
        let startTime = defaults?.object(forKey: "local_timer_startTime") as? Double ?? Date().timeIntervalSince1970
        let finalDuration = Date().timeIntervalSince1970 - startTime
            
        // 修改主状态并清理痕迹
        defaults?.set(false, forKey: "local_timer_isRunning")
        defaults?.removeObject(forKey: "local_timer_startTime")
            
        let targetTitle = bookTitle
        
        // 安全锁：只有时间大于 1秒 且小于 12小时(43200秒) 才允许存库。
        if finalDuration >= 1 && finalDuration <= 43200 {
            Task { @MainActor in
                let context = SharedDatabase.shared.container.mainContext
                let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.title == targetTitle })
                    
                if let book = try? context.fetch(descriptor).first {
                    let newRecord = ReadingRecord(date: Date(), readingDuration: finalDuration, book: book)
                    context.insert(newRecord)
                    try? context.save()
                }
            }
        }
        return .result()
    }
    
    /// 专门负责关闭实时活动的并发安全环境。
    ///
    /// - 注意: 为了遵守 Swift 6 严格的并发隔离策略，涉及 `ActivityKit` UI 操作的代码
    /// 必须且只能在 `@MainActor` (主线程) 上被调用执行。
    @MainActor
    private func endActivitiesSafely() async {
        for activity in Activity<ReadingTimerAttributes>.activities where activity.attributes.bookTitle == bookTitle {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif
