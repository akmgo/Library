#if os(macOS)
import SwiftUI
import SwiftData
internal import Combine

@MainActor
class AppleBooksImporter: ObservableObject {
    static let shared = AppleBooksImporter()
    
    @Published var isImporting = false
    @Published var importLogs: [String] = []
    
    private func log(_ message: String) {
        importLogs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
    }
    
    /// 执行纯净版全量数据迁移
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
