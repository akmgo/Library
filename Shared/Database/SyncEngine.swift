#if os(macOS)
import SwiftUI
import SwiftData
internal import Combine

/// 负责从原生 Apple Books 不断汲取最新进度和摘录的后台心跳引擎。
///
/// 这是 macOS 端独有的自动同步机制。它会根据 App 当前的生命周期 (`ScenePhase`)，
/// 动态调整底层的循环轮询策略（前台高频，后台低频）。
@MainActor
class SyncEngine: ObservableObject {
    /// 唯一共享实例。
    static let shared = SyncEngine()
    
    /// 标志位：表明当前同步任务是否正在执行，防止并发轮询重叠。
    @Published var isSyncing: Bool = false
    
    /// 暴露给 UI 的近期同步运行日志数组，仅保留最新两条。
    @Published var recentLogs: [String] = []
    
    /// 掌控后台轮询循环的并发任务令牌。
    private var syncTask: Task<Void, Never>? = nil
    private let logStorageKey = "MyLibrarySyncLogs"
    
    init() {
        self.recentLogs = UserDefaults.standard.stringArray(forKey: logStorageKey) ?? []
    }
    
    /// 追加同步格式化日志，限制最大长度并将结果保存至 UserDefaults。
    private func addLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        let timeString = formatter.string(from: Date())
        
        let newLog = "[\(timeString)] \(message)"
        recentLogs.insert(newLog, at: 0)
        if recentLogs.count > 2 { recentLogs = Array(recentLogs.prefix(2)) }
        UserDefaults.standard.set(recentLogs, forKey: logStorageKey)
    }
    
    /// 监听窗口焦点事件，动态调整调度频率。
    ///
    /// - Parameter phase: 当前的应用场景阶段。
    /// 前台激活时设定为 10 分钟 (600秒) 轮询，后台隐匿时降频至 1 小时 (3600秒)。
    func handleScenePhase(_ phase: ScenePhase) {
        if phase == .active {
            performFullSync()
            startSyncLoop(interval: 600)
        } else if phase == .background || phase == .inactive {
            startSyncLoop(interval: 3600)
        }
    }
    
    /// 启动具备自动睡眠和唤醒机制的异步任务循环。
    private func startSyncLoop(interval: TimeInterval) {
        syncTask?.cancel()
        syncTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if !Task.isCancelled { self.performFullSync() }
            }
        }
    }
    
    /// 执行一次全量同步对比事务。
    ///
    /// **逻辑流：**
    /// 1. 挂起锁并提取 SwiftData 中所有标记为 `reading` 的焦点书籍。
    /// 2. 通过书名桥接底层 `AppleBooksDBUtils`，获取它在苹果官方阅读器里的最新进度与最新摘录。
    /// 3. 若发现摘录内容在本地不存在，建立 `Excerpt` 模型并存入当前书籍关系网中。
    /// 4. 检测到状态变动后进行合并 `save()`，并向上层派发日志。
    func performFullSync() {
        if isSyncing { return }
        isSyncing = true
        defer { isSyncing = false }
        
        let context = SharedDatabase.shared.container.mainContext
        var logMessage = "数据已是最新的。"
        
        do {
            // 终极绝杀解法：放弃 Predicate，直接拉取所有书籍，在内存中过滤。
            let descriptor = FetchDescriptor<Book>()
            let allBooks = try context.fetch(descriptor)
            
            // 内存过滤出阅读中的书
            let readingBooks = allBooks.filter { $0.status == .reading }
            
            if let currentBook = readingBooks.first {
                let safeTitle = currentBook.title ?? ""
                let safeProgress = currentBook.progress
                var addedExcerptsCount = 0
                var progressUpdated = false
                
                if let appleProgress = AppleBooksDBUtils.fetchBookProgress(byTitle: safeTitle), appleProgress != safeProgress {
                    currentBook.progress = appleProgress
                    progressUpdated = true
                }
                
                if let assetId = AppleBooksDBUtils.fetchAssetId(byTitle: safeTitle) {
                    let appleExcerpts = AppleBooksDBUtils.fetchAnnotations(forAssetId: assetId)
                    for appleAnn in appleExcerpts {
                        let cleanText = appleAnn.text
                            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”「」『』'‘’"))
                            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        
                        if cleanText.isEmpty { continue }
                        
                        let exists = currentBook.excerpts?.contains(where: { ($0.content ?? "") == cleanText }) ?? false
                        if !exists {
                            let newExcerpt = Excerpt(content: cleanText, createdAt: appleAnn.creationDate)
                            newExcerpt.book = currentBook
                            context.insert(newExcerpt)
                            if currentBook.excerpts == nil { currentBook.excerpts = [] }
                            currentBook.excerpts?.append(newExcerpt)
                            addedExcerptsCount += 1
                        }
                    }
                }
                
                if progressUpdated || addedExcerptsCount > 0 {
                    logMessage = "同步:《\(safeTitle.prefix(6))..》"
                    if progressUpdated { logMessage += "进度 \(currentBook.progress)%" }
                    if addedExcerptsCount > 0 { logMessage += " 摘录 +\(addedExcerptsCount)" }
                    try context.save()
                }
            } else {
                logMessage = "当前无在读焦点，跳过同步。"
            }
        } catch {
            logMessage = "本地数据库读取失败。"
        }
        self.addLog(logMessage)
    }
}
#endif
