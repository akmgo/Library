#if os(macOS)
import Foundation
import SwiftData

@MainActor
final class AppleBooksParser {
    
    enum ParseError: Error, LocalizedError {
        case emptyText
        case invalidFormat
        case saveFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .emptyText: return "获取到的文本为空。"
            case .invalidFormat: return "无法识别格式，请确保分享的是 Apple Books 导出的内容。"
            case .saveFailed(let msg): return "数据保存失败: \(msg)"
            }
        }
    }
    
    static func parse(text: String, context: ModelContext) throws -> (bookTitle: String, annotationCount: Int) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { throw ParseError.emptyText }
        
        let rawLines = cleanText.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard lines.count >= 2 else { throw ParseError.invalidFormat }
        
        // 智能路由
        if lines[0].contains("笔记摘自") {
            return try parseBatchFormat(lines: lines, context: context)
        } else {
            return try parseSingleAndShareFormat(lines: lines, context: context)
        }
    }
    
    // MARK: - 🚀 解析批量分享格式 (邮件导出流)
    private static func parseBatchFormat(lines: [String], context: ModelContext) throws -> (bookTitle: String, annotationCount: Int) {
        // ... (保持原样，完美运行)
        var title = lines[1]
        if title.hasPrefix("《") && title.hasSuffix("》") { title = String(title.dropFirst().dropLast()) }
        let author = lines[2]
        
        let targetBook = getOrCreateBook(title: title, author: author, context: context)
        var annotationCount = 0
        var currentBuffer: [String] = []
        
        func flushBuffer() {
            if !currentBuffer.isEmpty {
                let content = currentBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !content.isEmpty {
                    let annotation = BookAnnotation(content: content, type: .excerpt, book: targetBook)
                    context.insert(annotation)
                    annotationCount += 1
                }
                currentBuffer.removeAll()
            }
        }
        
        for line in lines[3...] {
            if line.contains("所有摘录来自") { flushBuffer(); break }
            if isLikelyDateLine(line) { flushBuffer(); continue }
            currentBuffer.append(line)
        }
        flushBuffer()
        
        do {
            try context.save()
            return (title, annotationCount)
        } catch {
            throw ParseError.saveFailed(error.localizedDescription)
        }
    }
    
    // MARK: - 🛡️ 解析单条与右键分享格式 (核心修复点)
    private static func parseSingleAndShareFormat(lines: [String], context: ModelContext) throws -> (bookTitle: String, annotationCount: Int) {
        guard let footerIndex = lines.lastIndex(where: {
            $0.contains("摘录来自：") || $0.contains("摘录来自:") || $0.lowercased().contains("excerpt from")
        }) else { throw ParseError.invalidFormat }
        
        let footerLine = lines[footerIndex]
        var title = ""
        var author = "未知作者"
        
        // 1. 甄别是否为 Share Extension 分享出来的单行压缩格式
        if footerLine.lowercased().contains("apple books") {
            var cleanFooter = footerLine
            // 剥去前缀
            if let range = cleanFooter.range(of: "摘录来自: ") { cleanFooter.removeSubrange(cleanFooter.startIndex..<range.upperBound) }
            else if let range = cleanFooter.range(of: "Excerpt from: ", options: .caseInsensitive) { cleanFooter.removeSubrange(cleanFooter.startIndex..<range.upperBound) }
            // 剥去后缀
            cleanFooter = cleanFooter.replacingOccurrences(of: " Apple Books.", with: "")
            cleanFooter = cleanFooter.replacingOccurrences(of: " Apple Books", with: "")
            
            // 此时剩下：加西亚·马尔克斯. “霍乱时期的爱情.”
            if let quoteStart = cleanFooter.firstIndex(of: "“"), let quoteEnd = cleanFooter.lastIndex(of: "”") {
                let titleRaw = String(cleanFooter[cleanFooter.index(after: quoteStart)..<quoteEnd])
                title = titleRaw.hasSuffix(".") || titleRaw.hasSuffix("。") ? String(titleRaw.dropLast()) : titleRaw
                let authorRaw = String(cleanFooter[..<quoteStart])
                author = authorRaw.replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
            } else {
                title = cleanFooter
            }
        } else {
            // 2. 老的手动全选复制格式 (书名和作者在下面几行)
            guard footerIndex + 1 < lines.count else { throw ParseError.invalidFormat }
            title = lines[footerIndex + 1]
            if title.hasPrefix("《") && title.hasSuffix("》") { title = String(title.dropFirst().dropLast()) }
            if footerIndex + 2 < lines.count {
                let potentialAuthor = lines[footerIndex + 2]
                if !potentialAuthor.contains("版权") && !potentialAuthor.lowercased().contains("copyright") {
                    author = potentialAuthor
                }
            }
        }
        
        guard !title.isEmpty else { throw ParseError.invalidFormat }
        let targetBook = getOrCreateBook(title: title, author: author, context: context)
        
        // 3. 提取正文 (由于分享格式可能是多行，先拼合再脱外套)
        var contentLines = Array(lines[0..<footerIndex])
        if !contentLines.isEmpty && isLikelyDateLine(contentLines[0]) {
            contentLines.removeFirst() // 防御性过滤可能存在的独立日期行
        }
        
        var content = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 扒掉首尾的全角或半角双引号
        if (content.hasPrefix("“") && content.hasSuffix("”")) || (content.hasPrefix("\"") && content.hasSuffix("\"")) {
            content = String(content.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard !content.isEmpty else { throw ParseError.invalidFormat }
        
        let annotation = BookAnnotation(content: content, type: .excerpt, book: targetBook)
        context.insert(annotation)
        
        do {
            try context.save()
            return (title, 1)
        } catch {
            throw ParseError.saveFailed(error.localizedDescription)
        }
    }
    
    // MARK: - 辅助方法
    private static func isLikelyDateLine(_ line: String) -> Bool {
        if line.count > 30 { return false }
        let dateKeywords = ["年", "月", "日", "星期", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        for keyword in dateKeywords {
            if line.contains(keyword) && line.rangeOfCharacter(from: .decimalDigits) != nil {
                return true
            }
        }
        return false
    }
    
    private static func getOrCreateBook(title: String, author: String, context: ModelContext) -> Book {
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.title == title })
        if let existingBooks = try? context.fetch(descriptor), let firstBook = existingBooks.first { return firstBook }
        else {
            let newBook = Book(title: title, author: author, status: .reading)
            context.insert(newBook)
            return newBook
        }
    }
}
#endif
