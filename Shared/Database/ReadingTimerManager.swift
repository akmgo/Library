import Foundation
import SwiftData
import WidgetKit
import SwiftUI
internal import Combine

@MainActor
class ReadingTimerManager: ObservableObject {
    static let shared = ReadingTimerManager()
    
    // 💡 直接实例化 UserDefaults，杜绝任何访问控制权限报错
    private let defaults = UserDefaults(suiteName: "group.com.akram.library") ?? UserDefaults.standard
    
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentBookTitle: String = ""
    @Published var startTime: Date = Date()
    
    private init() {
        self.isRunning = defaults.bool(forKey: "local_timer_isRunning")
        self.currentBookTitle = defaults.string(forKey: "local_timer_bookTitle") ?? ""
        let timestamp = defaults.double(forKey: "local_timer_startTime")
        if timestamp > 0 { self.startTime = Date(timeIntervalSince1970: timestamp) }
    }
    
    func syncStateFromRemote() {
            self.isRunning = defaults.bool(forKey: "local_timer_isRunning")
            self.isPaused = defaults.bool(forKey: "is_timer_paused")
            // 如果发现已经停止了，更新本地 UI
        }
    
    /// 🚀 开启本机计时
    func startReading(bookTitle: String) {
        self.isRunning = true
        self.currentBookTitle = bookTitle
        self.startTime = Date()
        
        defaults.set(true, forKey: "local_timer_isRunning")
        defaults.set(bookTitle, forKey: "local_timer_bookTitle")
        defaults.set(self.startTime.timeIntervalSince1970, forKey: "local_timer_startTime")
        
        // ✨ 呼叫小组件立刻刷新
        WidgetCenter.shared.reloadTimelines(ofKind: "ReadingTimerWidget")
    }
    
    /// 🛑 结束计时，合并当前书籍的今日数据
    func stopReading(context: ModelContext, book: Book) {
        guard isRunning else { return }
        let duration = Date().timeIntervalSince(startTime) // 获得秒数
        
        // 1. 清理本机状态与 UI
        self.isRunning = false
        defaults.set(false, forKey: "local_timer_isRunning")
        WidgetCenter.shared.reloadTimelines(ofKind: "ReadingTimerWidget")
        
        // 2. ✨ 数据合并逻辑：同一天、同一本书，直接累加
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
