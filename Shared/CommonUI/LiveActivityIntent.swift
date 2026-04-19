#if os(iOS)
import ActivityKit
import AppIntents
import SwiftData
import SwiftUI

/// ⏹️ 唯一交互：停止计时 Intent
struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "结束并保存"
        
    @Parameter(title: "Book Title")
    var bookTitle: String
        
    init() {}
    init(bookTitle: String) {
        self.bookTitle = bookTitle
    }
        
    func perform() async throws -> some IntentResult {
        // 1. 关闭锁屏 UI
        for activity in Activity<ReadingTimerAttributes>.activities where activity.attributes.bookTitle == bookTitle {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
            
        let defaults = UserDefaults(suiteName: "group.com.akram.library")
            
        // ✨ 核心修复 1：必须用 object 强转，杜绝返回 1970 年的 0.0！
        let startTime = defaults?.object(forKey: "local_timer_startTime") as? Double ?? Date().timeIntervalSince1970
        let finalDuration = Date().timeIntervalSince1970 - startTime
            
        // 修改主状态并清理痕迹
        defaults?.set(false, forKey: "local_timer_isRunning")
        defaults?.removeObject(forKey: "local_timer_startTime")
            
        let targetTitle = bookTitle
        // ✨ 核心修复 2：加上安全锁。只有时间大于 1秒，且小于 12小时(43200秒) 才允许存库
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
    
    /// ✨ 核心修复：建立主线程隔离区，专门伺候骄气的 ActivityKit
    @MainActor
    private func endActivitiesSafely() async {
        for activity in Activity<ReadingTimerAttributes>.activities where activity.attributes.bookTitle == bookTitle {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif
