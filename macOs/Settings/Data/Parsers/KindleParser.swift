#if os(macOS)
import Foundation
import SwiftData

@MainActor
final class KindleParser {
    
    enum ParseError: Error, LocalizedError {
        case unreadableFile
        case noDataFound
        case saveFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .unreadableFile: return "无法读取该文件，请确保它是一个合法的 My Clippings.txt 文件。"
            case .noDataFound: return "在文件中没有找到任何有效的笔记或摘录。"
            case .saveFailed(let msg): return "数据保存失败: \(msg)"
            }
        }
    }
    
    /// 解析 Kindle 的 My Clippings.txt 并直接写入数据库
    static func parse(fileURL: URL, context: ModelContext) throws -> (booksCount: Int, annotationCount: Int) {
        // 1. 读取文件并处理编码问题
        guard let fileContent = try? String(contentsOf: fileURL, encoding: .utf8) else {
            throw ParseError.unreadableFile
        }
        
        // 2. 数据清洗：
        // 移除文件头部可能存在的 UTF-8 BOM 隐藏字符 (\u{FEFF})
        // 统一换行符 (Kindle 经常混用 \r\n 和 \n)
        let cleanContent = fileContent
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
        
        // 3. 核心大砍刀：按 ========== 分割成独立的数据块
        let blocks = cleanContent.components(separatedBy: "==========")
        
        var parsedBooks = [String: Book]() // 用于缓存当前解析中创建的书籍，避免重复查库
        var annotationCount = 0
        
        for block in blocks {
            // 将每个块按行切分，并丢弃首尾的空白行
            let lines = block.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            // 一个合法的 clipping 块至少要有 3 行：书名作者行、元数据行、正文内容
            guard lines.count >= 3 else { continue }
            
            // --- A. 解析书名与作者 ---
            let titleAuthorLine = lines[0]
            let (title, author) = extractTitleAndAuthor(from: titleAuthorLine)
            
            // 跳过无效书名
            if title.isEmpty { continue }
            
            // --- B. 解析笔记类型 (第二行) ---
            let metaLine = lines[1].lowercased()
            // 过滤掉 Kindle 自动生成的无用书签 (Bookmark)
            if metaLine.contains("bookmark") || metaLine.contains("书签") {
                continue
            }
            
            let annotationType: AnnotationType = (metaLine.contains("note") || metaLine.contains("笔记") || metaLine.contains("想法")) ? .note : .excerpt
            
            // --- C. 提取正文内容 ---
            // 剩下的所有行拼起来就是正文
            let contentLines = lines[2...]
            let content = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            
            if content.isEmpty { continue }
            
            // --- D. 关联或创建书籍 ---
            let targetBook: Book
            if let cachedBook = parsedBooks[title] {
                targetBook = cachedBook
            } else {
                targetBook = getOrCreateBook(title: title, author: author, context: context)
                parsedBooks[title] = targetBook
            }
            
            // --- E. 写入摘录/笔记 ---
            // 简单去重：检查该书下是否已经存在完全相同的摘录 (防止用户重复导入同一个 txt)
            let isDuplicate = targetBook.annotations?.contains(where: { $0.content == content }) ?? false
            if !isDuplicate {
                let annotation = BookAnnotation(content: content, type: annotationType, book: targetBook)
                context.insert(annotation)
                annotationCount += 1
            }
        }
        
        guard annotationCount > 0 else { throw ParseError.noDataFound }
        
        do {
            try context.save()
            return (parsedBooks.count, annotationCount)
        } catch {
            throw ParseError.saveFailed(error.localizedDescription)
        }
    }
    
    // MARK: - 智能解析工具
    
    /// 从类似 "百年孤独 (加西亚·马尔克斯)" 的字符串中安全剥离书名和作者
    private static func extractTitleAndAuthor(from line: String) -> (title: String, author: String) {
        var title = line
        var author = "未知作者"
        
        // 查找最后一个左括号和右括号
        if let lastOpenParen = line.lastIndex(of: "(") ?? line.lastIndex(of: "（"),
           let lastCloseParen = line.lastIndex(of: ")") ?? line.lastIndex(of: "）"),
           lastOpenParen < lastCloseParen {
            
            // 如果右括号确实在字符串的末尾附近
            let distanceToEnd = line.distance(from: lastCloseParen, to: line.endIndex)
            if distanceToEnd <= 2 {
                title = String(line[..<lastOpenParen]).trimmingCharacters(in: .whitespaces)
                let authorRange = line.index(after: lastOpenParen)..<lastCloseParen
                author = String(line[authorRange]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // 去除残留的书名号
        if title.hasPrefix("《") && title.hasSuffix("》") {
            title = String(title.dropFirst().dropLast())
        }
        
        return (title, author)
    }
    
    /// 查库以保证不重复创建同名书籍
    private static func getOrCreateBook(title: String, author: String, context: ModelContext) -> Book {
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.title == title })
        if let existingBooks = try? context.fetch(descriptor), let firstBook = existingBooks.first {
            return firstBook
        } else {
            let newBook = Book(title: title, author: author, status: .finished) // Kindle导出的通常按已读处理
            context.insert(newBook)
            return newBook
        }
    }
}
#endif
