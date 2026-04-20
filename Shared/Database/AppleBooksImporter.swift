#if os(macOS)
import SwiftUI
import SwiftData
internal import Combine

/// 负责将 Apple Books 数据全量同步至本地 SwiftData 的调度引擎。
///
/// 这是一个遵循 `ObservableObject` 的单例管理器，专供 macOS 导入设置页面使用。
///
/// **核心职责：**
/// 1. 发起从 Apple Books 数据库拉取原生数据的请求。
/// 2. 进行中文书籍清洗、剔重、以及焦点计算（谁是当前继续阅读的目标）。
/// 3. 执行安全的跨库写入或增量合并更新，并将导入进度日志实时推送到 UI 控制台。
@MainActor
class AppleBooksImporter: ObservableObject {
    /// 唯一共享实例
    static let shared = AppleBooksImporter()
    
    /// 控制当前是否正在进行高耗时的数据库导入任务（UI 层可用来禁用导入按钮并展示菊花）。
    @Published var isImporting = false
    
    /// 实时收集导入流程中的文字追踪日志，驱动前端进度板刷新。
    @Published var importLogs: [String] = []
    
    /// 记录结构化日志内容并推入堆栈。
    private func log(_ message: String) {
        importLogs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
    }
    
    /// 执行纯净版的全量数据迁移与清洗逻辑。
    ///
    /// - 逻辑流：
    ///   1. 调用底层工具获取全量图书元数据。
    ///   2. **过滤降噪**：仅保留标题纯中文（且不含英文字母）的书籍并去重。
    ///   3. **焦点确立**：根据 `lastOpenDate` 从这批书中找出唯一一本“当前在读”，其余全部归档为已读/未读。
    ///   4. **跨库增量对齐**：遍历过滤后的书单，如果在 SwiftData 中已存在，则合并最新进度状态；如果不存在，则实例化新 `Book` 插入。
    ///   5. **摘录回流**：按需拉取每一本书在 Apple Books 里的划线，如果本地没有则实例化为 `Excerpt` 建立关联。
    ///
    /// - Parameters:
    ///   - modelContext: 用于执行持久化存储的 SwiftData 上下文容器。
    ///   - existingBooks: 目前库中已经存在的全量旧书单（用于去重校验）。
    ///   - onCompletion: 导入顺利完成、状态复位后，触发的异步回调动作。
    func performFullMigration(modelContext: ModelContext, existingBooks: [Book], onCompletion: @escaping () -> Void) async {
        guard !isImporting else { return }
        isImporting = true
        importLogs.removeAll()
        
        log("🚀 开始全量扫描 Apple Books 数据库...")
        
        let rawAppleBooks = AppleBooksDBUtils.fetchAllBooks()
        log("🔍 底层发现 \(rawAppleBooks.count) 本原始数据。开始清洗与过滤...")
        
        var uniqueBooks: [AppleBookInfo] = []
        var seenTitles = Set<String>()
        
        for book in rawAppleBooks {
            // 过滤非纯中文书籍
            let hasChinese = book.title.range(of: "\\p{Han}", options: .regularExpression) != nil
            let hasEnglish = book.title.range(of: "[a-zA-Z]", options: .regularExpression) != nil
            if !hasChinese || hasEnglish { continue }
            
            // 去重
            if !seenTitles.contains(book.title) {
                seenTitles.insert(book.title)
                uniqueBooks.append(book)
            }
        }
        
        log("📚 过滤后剩余 \(uniqueBooks.count) 本有效纯中文书籍。")
        
        // ========================================================
        // ✨ 定位唯一“继续阅读”的目标
        // ========================================================
        let activeBook = uniqueBooks
            .filter { $0.progress > 0 && $0.progress < 100 && $0.lastOpenDate != nil }
            .max(by: { $0.lastOpenDate! < $1.lastOpenDate! })
        
        if let currentActive = activeBook {
            log("🎯 定位到继续阅读目标：《\(currentActive.title)》，进度 \(currentActive.progress)%")
            // 保证排他性：把本地所有在读书籍降级为待读
            for b in existingBooks where b.status == .reading {
                b.status = .unread // ✨ 修复：枚举赋值
            }
        }
        
        var addedCount = 0
        var updatedCount = 0
        
        for appleBook in uniqueBooks {
            let isTheActiveBook = (appleBook.assetId == activeBook?.assetId)
            
            // ✨ 核心逻辑修复：使用真实的 BookStatus 枚举代替字符串
            let finalStatus: BookStatus = isTheActiveBook ? .reading : (appleBook.progress > 0 ? .finished : .unread)
            let finalProgress = isTheActiveBook ? appleBook.progress : (appleBook.progress > 0 ? 100 : 0)
            
            let targetBook: Book
            if let existing = existingBooks.first(where: { $0.title == appleBook.title }) {
                targetBook = existing
                targetBook.status = finalStatus
                targetBook.progress = finalProgress
                updatedCount += 1
            } else {
                targetBook = Book(
                    title: appleBook.title,
                    author: appleBook.author,
                    coverData: nil,
                    status: finalStatus, // ✨ 修复：枚举传入
                    rating: 0,
                    tags: ["AppleBooks"],
                    startTime: nil,
                    endTime: nil,
                    progress: finalProgress,
                    isWantToRead: false
                )
                modelContext.insert(targetBook)
                addedCount += 1
            }
            
            // 摘录注入
            let appleAnnotations = AppleBooksDBUtils.fetchAnnotations(forAssetId: appleBook.assetId)
            var newExcerptCount = 0
            for ann in appleAnnotations {
                let cleanText = ann.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanText.isEmpty { continue }
                
                let alreadyExists = targetBook.excerpts?.contains(where: { ($0.content ?? "") == cleanText }) ?? false
                if !alreadyExists {
                    let newExcerpt = Excerpt(content: cleanText, createdAt: ann.creationDate)
                    newExcerpt.book = targetBook
                    modelContext.insert(newExcerpt)
                    if targetBook.excerpts == nil { targetBook.excerpts = [] }
                    targetBook.excerpts?.append(newExcerpt)
                    newExcerptCount += 1
                }
            }
            if newExcerptCount > 0 { log("📝 《\(appleBook.title)》新入库 \(newExcerptCount) 条摘录。") }
            try? modelContext.save()
        }
        
        log("✅ 迁移完成！新增 \(addedCount) 本，更新 \(updatedCount) 本。")
        isImporting = false
        
        DispatchQueue.main.async { onCompletion() }
    }
}
#endif
