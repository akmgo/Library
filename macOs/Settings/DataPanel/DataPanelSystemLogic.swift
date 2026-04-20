#if os(macOS)
import AppKit
import SwiftUI
import SwiftData

// MARK: - ✨ 系统动作与核心运维扩展

/// 负责调度高能耗、高权限操作（如导出沙盒文件、跨库同步、系统删表）的逻辑扩展。
extension DataPanelSettingsView {
    
    // MARK: - Apple Books 穿透同步
    
    /// 唤起后台并发进程，穿透读取系统 Apple Books 数据库并合并到本地 SwiftData。
    internal func executeFullAppleBooksMigration() {
        showPlainFeedback("🚀 正在穿透抓取 Apple Books 全量数据...")
        Task {
            await importer.performFullMigration(modelContext: modelContext, existingBooks: allBooks) {
                // 同步完成后，主动展开图片选择器帮助用户修补封面
                showCoverPicker = true
            }
        }
    }

    /// 对用户选定的图片路径群进行访问授权及读取，通过书名字典映射关系。
    internal func handleCoverImport(result: Result<[URL], Error>) {
        guard let urls = try? result.get(), !urls.isEmpty else {
            showPlainFeedback("⚠️ 封面选择已跳过。")
            return
        }
        var tempCovers: [String: Data] = [:]
        var updatedDBCount = 0
            
        for url in urls {
            // 获取沙盒外安全读写权限
            if url.startAccessingSecurityScopedResource() {
                let bookTitle = url.deletingPathExtension().lastPathComponent
                if let data = try? Data(contentsOf: url) {
                    tempCovers[bookTitle] = data
                    if let existingBook = allBooks.first(where: { $0.title == bookTitle }) {
                        existingBook.coverData = data
                        updatedDBCount += 1
                    }
                }
                url.stopAccessingSecurityScopedResource()
            }
        }
            
        DispatchQueue.main.async {
            self.matchedCovers = tempCovers
            if updatedDBCount > 0 {
                try? self.modelContext.save()
                var log = AttributedString("🎉 完美！成功自动装配了 ")
                var countStr = AttributedString("\(updatedDBCount)"); countStr.foregroundColor = .green; countStr.font = .system(size: 14, weight: .bold)
                log.append(countStr); log.append(AttributedString(" 张高清封面！"))
                self.showRichFeedback(log)
            } else {
                self.showPlainFeedback("⚠️ 成功读取图片，但图片名未能与本地书名匹配上。")
            }
        }
    }
    
    // MARK: - 本地数据导出引擎
    
    /// 调用全局唯一的导出服务，利用原生 `NSOpenPanel` 备份 JSON 资产至物理硬盘。
    internal func executeDataExport() {
        isExporting = true
        showPlainFeedback("📦 正在打包导出数据，请稍候...")
        Task {
            do {
                if let destinationURL = try await DataExportService.shared.exportBooks(allBooks) {
                    DispatchQueue.main.async {
                        var log = AttributedString("✅ 导出成功！已保存至：")
                        var folderName = AttributedString(destinationURL.lastPathComponent); folderName.foregroundColor = .indigo; folderName.font = .system(size: 13, weight: .bold)
                        log.append(folderName)
                        self.showRichFeedback(log)
                        self.isExporting = false
                        // 触发系统 Finder 自动弹开并选中导出的目录
                        NSWorkspace.shared.open(destinationURL)
                    }
                } else {
                    DispatchQueue.main.async { self.isExporting = false }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showPlainFeedback("❌ 导出失败：\(error.localizedDescription)")
                    self.isExporting = false
                }
            }
        }
    }
    
    // MARK: - 危险数据销毁
    
    /// 根据选择性删除清单，精准定向清理内存与关联上下文。
    internal func executeSelectiveDeletion() {
        var deletedCount = 0
        for bookID in booksToDelete {
            if let book = allBooks.first(where: { $0.id == bookID }) { modelContext.delete(book); deletedCount += 1 }
        }
        do {
            try modelContext.save()
            var log = AttributedString("🗑️ 成功清理了 ")
            var countStr = AttributedString("\(deletedCount)"); countStr.foregroundColor = .red; countStr.font = .system(size: 14, weight: .bold)
            log.append(countStr); log.append(AttributedString(" 本书籍及其所有的关联数据。"))
            showRichFeedback(log)
            booksToDelete.removeAll()
        } catch { showPlainFeedback("❌ 清理失败，请检查数据库状态。") }
    }
    
    /// [警告] 级联物理清空整个应用内的数据。
    internal func deleteAllLocalData() {
        do {
            try modelContext.delete(model: Book.self)
            try modelContext.delete(model: Excerpt.self)
            try modelContext.delete(model: Note.self)
            try modelContext.delete(model: ReadingRecord.self)
            try modelContext.save()
            showPlainFeedback("🗑️ 本地所有数据已彻底清空。")
        } catch { showPlainFeedback("❌ 清空数据失败") }
    }
    
    // MARK: - 系统吐司回执控制
    
    /// 在顶部显示一段无格式的纯文本动态通知气泡。
    internal func showPlainFeedback(_ msg: String) {
        showRichFeedback(AttributedString(msg))
    }
    
    /// 在顶部显示一段拥有高亮属性控制的富文本动态通知气泡。
    internal func showRichFeedback(_ msg: AttributedString) {
        withAnimation { self.systemMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { withAnimation { self.systemMessage = nil } }
    }
}
#endif
