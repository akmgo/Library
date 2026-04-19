#if os(macOS)
import AppKit
import Foundation
import SwiftData

// MARK: - 📦 导出数据结构 (DTO)

// 这些结构体专为导出 JSON 设计，完全脱离 SwiftData 的上下文

struct ExportArchive: Codable {
    let exportTime: Date
    let totalBooks: Int
    let books: [ExportBook]
}

struct ExportBook: Codable {
    let title: String
    let author: String
    let rating: Int?
    let tags: [String]?
    let startTime: Date?
    let endTime: Date?
    let status: String
    let excerpts: [ExportExcerpt]
    let notes: [ExportNote]
    let coverFileName: String? // 指向 Covers 文件夹中的图片名称
}

struct ExportExcerpt: Codable {
    let content: String
    let createdAt: Date?
}

struct ExportNote: Codable {
    let content: String
    let createdAt: Date?
}

// MARK: - 🚀 核心导出引擎

@MainActor
final class DataExportService {
    static let shared = DataExportService()
    private init() {}
    
    /// 执行导出流程，返回导出的目标文件夹 URL
    func exportBooks(_ books: [Book]) async throws -> URL? {
        // 1. 弹出 macOS 原生文件夹选择器
        let openPanel = NSOpenPanel()
        openPanel.title = "选择导出位置"
        openPanel.message = "请选择一个文件夹来保存您的阅读数据备份"
        openPanel.prompt = "导出到这里"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        
        let response = openPanel.runModal()
        guard response == .OK, let destinationURL = openPanel.url else {
            return nil // 用户取消了操作
        }
        
        // 2. 创建本次导出的根目录 (例如: MyLibrary_Export_20260413_1530)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let folderName = "MyLibrary_Export_\(formatter.string(from: Date()))"
        let rootExportURL = destinationURL.appendingPathComponent(folderName, isDirectory: true)
        
        let coversURL = rootExportURL.appendingPathComponent("Covers", isDirectory: true)
        
        // 执行文件创建
        try FileManager.default.createDirectory(at: rootExportURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: coversURL, withIntermediateDirectories: true)
        
        // 3. 组装数据并写入封面
        var exportBooks: [ExportBook] = []
        
        for book in books {
            let safeTitle = book.title ?? "未命名书籍"
            var coverFileName: String? = nil
            
            // 处理封面写入
            if let coverData = book.coverData {
                // ✨ 纯净命名：只用书名，过滤掉文件系统不允许的特殊字符（斜杠和冒号）
                let fileSafeTitle = safeTitle
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                            
                let fileName = "\(fileSafeTitle).jpg"
                let coverFileURL = coversURL.appendingPathComponent(fileName)
                            
                try coverData.write(to: coverFileURL)
                coverFileName = fileName
            }
            
            // 组装摘录
            let exportExcerpts = (book.excerpts ?? []).map { excerpt in
                ExportExcerpt(content: excerpt.content ?? "", createdAt: excerpt.createdAt)
            }
            
            // 组装笔记
            let exportNotes = (book.notes ?? []).map { note in
                ExportNote(content: note.content ?? "", createdAt: note.createdAt)
            }
            
            // ✨ 修复：获取枚举的 rawValue 转换为 String 导出
            let statusString = book.status?.rawValue ?? "UNKNOWN"
            
            // 组装书籍 DTO
            let exportBook = ExportBook(
                title: safeTitle,
                author: book.author ?? "未知作者",
                rating: book.rating,
                tags: book.tags,
                startTime: book.startTime,
                endTime: book.endTime,
                status: statusString,
                excerpts: exportExcerpts,
                notes: exportNotes,
                coverFileName: coverFileName
            )
            
            exportBooks.append(exportBook)
        }
        
        let archive = ExportArchive(exportTime: Date(), totalBooks: exportBooks.count, books: exportBooks)
        
        // 4. 将结构化数据序列化为 JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601 // 标准日期格式，方便其他语言解析
        
        let jsonData = try encoder.encode(archive)
        
        // 5. 写入 data.json 文件
        let jsonFileURL = rootExportURL.appendingPathComponent("data.json")
        try jsonData.write(to: jsonFileURL)
        
        return rootExportURL
    }
}
#endif
