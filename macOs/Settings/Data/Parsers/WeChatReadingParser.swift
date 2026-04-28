#if os(macOS)
import AppKit
import SwiftData

@MainActor
final class WeChatReadingParser {
    
    enum ParseError: Error, LocalizedError {
        case clipboardEmpty
        case invalidFormat
        case saveFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .clipboardEmpty: return "剪贴板为空，请先复制内容。"
            case .invalidFormat: return "无法识别格式，请确保复制的是微信读书导出的笔记内容。"
            case .saveFailed(let msg): return "数据保存失败: \(msg)"
            }
        }
    }
    
    static func parseFromClipboard(context: ModelContext) throws -> (bookTitle: String, annotationCount: Int) {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ParseError.clipboardEmpty
        }
        
        // 1. 数据清洗：统一换行符，并剔除所有的空行
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard lines.count >= 3 else { throw ParseError.invalidFormat }
        
        // 2. 提取书名
        var title = lines[0]
        if title.hasPrefix("《") && title.hasSuffix("》") {
            title = String(title.dropFirst().dropLast())
        }
        guard !title.isEmpty else { throw ParseError.invalidFormat }
        
        // 3. 提取作者
        let author = lines[1]
        
        // 4. 获取或创建书籍
        let targetBook = getOrCreateBook(title: title, author: author, context: context)
        
        // 5. 核心状态机引擎（基于 Debug 日志量身定制）
        var annotationCount = 0
        var currentBuffer: [String] = []
        var currentType: AnnotationType = .excerpt
        
        func flushBuffer() {
            if !currentBuffer.isEmpty {
                let content = currentBuffer.joined(separator: "\n")
                if !content.isEmpty {
                    let annotation = BookAnnotation(content: content, type: currentType, book: targetBook)
                    context.insert(annotation)
                    annotationCount += 1
                }
                currentBuffer.removeAll()
            }
        }
        
        // 找到 "个笔记" 所在的行，从它下一行开始处理正文
        guard let noteCountIndex = lines.firstIndex(where: { $0.contains("个笔记") }) else {
            throw ParseError.invalidFormat
        }
        
        for line in lines[(noteCountIndex + 1)...] {
            // 终止条件：遇到页脚立刻停工
            if line.contains("来自微信读书") {
                flushBuffer()
                break
            }
            
            // 触发条件：遇到黑菱形符号 ◆，说明是一条新的摘录/笔记的开始
            if line.hasPrefix("◆") {
                flushBuffer() // 先把上一条打包存好
                
                // 剔除前缀
                var cleanContent = String(line.dropFirst())
                cleanContent = cleanContent.trimmingCharacters(in: .whitespaces)
                
                // 简单判断一下是摘录还是想法 (如果微信以后加了标记的话)
                if cleanContent.hasPrefix("想法") || cleanContent.hasPrefix("点评") {
                    currentType = .note
                    // 去除可能的 "想法：" 之类的前缀
                    cleanContent = String(cleanContent.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanContent.hasPrefix(":") || cleanContent.hasPrefix("：") {
                        cleanContent = String(cleanContent.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else {
                    currentType = .excerpt
                    if cleanContent.hasPrefix("划线") {
                        cleanContent = String(cleanContent.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                currentBuffer.append(cleanContent)
                continue
            }
            
            // 多行文本接续：如果没有 ◆，但缓存区有文字，说明是上一条摘录由于换行断开了，接上去！
            if !currentBuffer.isEmpty {
                currentBuffer.append(line)
            }
            // 如果缓存区为空，且没有 ◆，这通常是章节标题（例如：自序 开启自我改变的原动力），直接跳过忽略。
        }
        
        flushBuffer() // 确保最后一条落盘
        
        do {
            try context.save()
            return (title, annotationCount)
        } catch {
            throw ParseError.saveFailed(error.localizedDescription)
        }
    }
    
    // MARK: - 辅助查询方法
    private static func getOrCreateBook(title: String, author: String, context: ModelContext) -> Book {
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.title == title })
        if let existingBooks = try? context.fetch(descriptor), let firstBook = existingBooks.first {
            return firstBook
        } else {
            let newBook = Book(title: title, author: author, status: .reading)
            context.insert(newBook)
            return newBook
        }
    }
}
#endif
