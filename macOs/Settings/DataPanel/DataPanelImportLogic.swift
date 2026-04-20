#if os(macOS)
import SwiftUI
import SwiftData

// MARK: - ✨ 导入与反序列化引擎扩展

/// 处理一切与外部文件加载、JSON 反序列化以及 SwiftData 安全插入相关的业务逻辑。
extension DataPanelSettingsView {
    
    /// 根据 ImportType 分发处理选取的 JSON 外部文件。
    internal func handleJSONImport(result: Result<URL, Error>, type: ImportType) {
        guard let url = try? result.get() else { return }
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                switch type {
                case .book:
                    let items = try jsonDecoder.decode([BookImportDTO].self, from: data)
                    DispatchQueue.main.async { self.pendingBooks = items; self.showPlainFeedback("📚 成功解析 \(items.count) 本书籍配置。") }
                case .excerpt:
                    let items = try jsonDecoder.decode([ExcerptImportDTO].self, from: data)
                    DispatchQueue.main.async { self.pendingExcerpts = items; self.showPlainFeedback("🔖 成功解析 \(items.count) 条摘录。") }
                case .note:
                    let items = try jsonDecoder.decode([NoteImportDTO].self, from: data)
                    DispatchQueue.main.async { self.pendingNotes = items; self.showPlainFeedback("📝 成功解析 \(items.count) 条笔记。") }
                case .record:
                    let items = try jsonDecoder.decode([ReadingRecordImportDTO].self, from: data)
                    DispatchQueue.main.async { self.pendingRecords = items; self.showPlainFeedback("📅 成功解析 \(items.count) 条阅读轨迹。") }
                }
            } catch { showPlainFeedback("❌ JSON 格式解析失败") }
        }
    }
    
    /// 执行打卡记录持久化。自带基于日期的智能防重校验。
    internal func executeRecordImport() {
        var count = 0
        let calendar = Calendar.current
        for dto in pendingRecords {
            guard let title = dto.bookTitle, let targetBook = allBooks.first(where: { $0.title == title }) else { continue }
            let finalDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dto.date) ?? dto.date
            
            let existingRecords = targetBook.readingRecords ?? []
            let exists = existingRecords.contains { record in calendar.isDate(record.date ?? Date(), inSameDayAs: finalDate) }
            
            if !exists {
                let newRecord = ReadingRecord(date: finalDate, book: targetBook)
                if let duration = dto.duration { newRecord.readingDuration = duration } else { newRecord.readingDuration = Double(Int.random(in: 1200 ... 4200)) }
                modelContext.insert(newRecord)
                if targetBook.readingRecords == nil { targetBook.readingRecords = [] }
                targetBook.readingRecords?.append(newRecord)
                count += 1
            }
        }
        do {
            try modelContext.save()
            var log = AttributedString("✅ 导入成功！共入库 "); var countStr = AttributedString("\(count)"); countStr.foregroundColor = .cyan
            log.append(countStr); log.append(AttributedString(" 天历史轨迹。"))
            showRichFeedback(log)
            pendingRecords.removeAll()
        } catch { showPlainFeedback("❌ 写入失败，请检查数据库状态。") }
    }
    
    /// 执行书籍元数据持久化。合并关联暂存池中的封面数据。
    internal func executeBookImport() {
        var count = 0; var matchedCount = 0; var skippedCount = 0; var unmatchedTitles: [String] = []
        let existingTitles = Set(allBooks.compactMap { $0.title })
            
        for dto in pendingBooks {
            if existingTitles.contains(dto.title) { skippedCount += 1; continue }
            let cover = matchedCovers[dto.title]
            if cover != nil { matchedCount += 1 } else { unmatchedTitles.append(dto.title) }
            
            let fallbackStatus = BookStatus(rawValue: dto.status ?? "UNREAD") ?? .unread
            let newBook = Book(title: dto.title, author: dto.author, coverData: cover, status: fallbackStatus, rating: dto.rating ?? 0, tags: dto.tags ?? [], startTime: dto.startTime, endTime: dto.endTime, progress: dto.progress ?? 0, isWantToRead: dto.isWantToRead ?? false)
            
            modelContext.insert(newBook)
            count += 1
        }
        do {
            try modelContext.save()
            var log = AttributedString("🎉 导入完毕！新增 "); var countStr = AttributedString("\(count)"); countStr.foregroundColor = .cyan
            log.append(countStr); log.append(AttributedString(" 本。其中 ")); var matchedStr = AttributedString("\(matchedCount)"); matchedStr.foregroundColor = .green
            log.append(matchedStr); log.append(AttributedString(" 本配对封面。"))
            if skippedCount > 0 { var skipStr = AttributedString(" 拦截重复 \(skippedCount) 本。"); skipStr.foregroundColor = .gray; log.append(skipStr) }
            if !unmatchedTitles.isEmpty { var warnStr = AttributedString("⚠️ 缺封面: \(unmatchedTitles.count)本"); warnStr.foregroundColor = .orange; log.append(warnStr) }
            showRichFeedback(log); pendingBooks.removeAll(); matchedCovers.removeAll()
        } catch { showPlainFeedback("❌ 写入失败") }
    }
    
    internal func executeExcerptImport() {
        var count = 0
        for dto in pendingExcerpts {
            let targetBook = allBooks.first(where: { $0.title == dto.bookTitle })
            let newExcerpt = Excerpt(content: dto.content, createdAt: dto.createdAt ?? Date(), book: targetBook)
            modelContext.insert(newExcerpt)
            if let tb = targetBook { if tb.excerpts == nil { tb.excerpts = [] }; tb.excerpts?.append(newExcerpt) }
            count += 1
        }
        try? modelContext.save()
        var log = AttributedString("✅ 导入成功！共入库 "); var countStr = AttributedString("\(count)"); countStr.foregroundColor = .orange
        log.append(countStr); log.append(AttributedString(" 条摘录。"))
        showRichFeedback(log); pendingExcerpts.removeAll()
    }
    
    internal func executeNoteImport() {
        var count = 0
        for dto in pendingNotes {
            let targetBook = allBooks.first(where: { $0.title == dto.bookTitle })
            let newNote = Note(content: dto.content, createdAt: dto.createdAt ?? Date(), book: targetBook)
            modelContext.insert(newNote)
            if let tb = targetBook { if tb.notes == nil { tb.notes = [] }; tb.notes?.append(newNote) }
            count += 1
        }
        try? modelContext.save()
        var log = AttributedString("✅ 导入成功！共入库 "); var countStr = AttributedString("\(count)"); countStr.foregroundColor = .purple
        log.append(countStr); log.append(AttributedString(" 条笔记。"))
        showRichFeedback(log); pendingNotes.removeAll()
    }
    
    /// 自动在指定的开始与结束时间中，逐日填充虚拟阅读流水，方便完善展示图表。
    internal func generateManualRecords() {
        guard let targetBook = allBooks.first(where: { $0.id == selectedBookIDForRecord }) else { return }
        let calendar = Calendar.current
        guard let start = calendar.startOfDay(for: recordStartDate) as Date?, let end = calendar.startOfDay(for: recordEndDate) as Date? else { return }
        
        var currentDate = start; var addedCount = 0
        while currentDate <= end {
            let existingRecords = targetBook.readingRecords ?? []
            let exists = existingRecords.contains { record in calendar.isDate(record.date ?? Date(), inSameDayAs: currentDate) }
            if !exists {
                let newRecord = ReadingRecord(date: currentDate, book: targetBook); newRecord.readingDuration = 1800
                modelContext.insert(newRecord)
                if targetBook.readingRecords == nil { targetBook.readingRecords = [] }
                targetBook.readingRecords?.append(newRecord)
                addedCount += 1
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }
        targetBook.startTime = start; targetBook.endTime = end; targetBook.status = .finished; targetBook.progress = 100
        try? modelContext.save()
        
        var log = AttributedString("✨ 轨迹生成完毕！为《\(targetBook.title ?? "")》添加了 ")
        var countStr = AttributedString("\(addedCount)"); countStr.foregroundColor = .mint
        log.append(countStr); log.append(AttributedString(" 天记录。"))
        showRichFeedback(log); selectedBookIDForRecord = ""
    }
}
#endif
