#if os(macOS)
import SwiftUI
import SwiftData
internal import Combine

@MainActor
class SyncEngine: ObservableObject {
    static let shared = SyncEngine()
    
    @Published var isSyncing: Bool = false
    @Published var recentLogs: [String] = []
    
    private var syncTask: Task<Void, Never>? = nil
    private let logStorageKey = "MyLibrarySyncLogs"
    
    init() {
        self.recentLogs = UserDefaults.standard.stringArray(forKey: logStorageKey) ?? []
    }
    
    private func addLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        let timeString = formatter.string(from: Date())
        
        let newLog = "[\(timeString)] \(message)"
        recentLogs.insert(newLog, at: 0)
        if recentLogs.count > 2 { recentLogs = Array(recentLogs.prefix(2)) }
        UserDefaults.standard.set(recentLogs, forKey: logStorageKey)
    }
    
    func handleScenePhase(_ phase: ScenePhase) {
        if phase == .active {
            performFullSync()
            startSyncLoop(interval: 600)
        } else if phase == .background || phase == .inactive {
            startSyncLoop(interval: 3600)
        }
    }
    
    private func startSyncLoop(interval: TimeInterval) {
        syncTask?.cancel()
        syncTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if !Task.isCancelled { self.performFullSync() }
            }
        }
    }
    
    func performFullSync() {
        if isSyncing { return }
        isSyncing = true
        defer { isSyncing = false }
        
        let context = SharedDatabase.shared.container.mainContext
        var logMessage = "数据已是最新的。"
        
        do {
            // ✨ 终极绝杀解法：放弃 Predicate，直接拉取所有书籍，在内存中过滤。
            // 保证 100% 成功，再也不会有宏报错了！
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
