#if os(macOS)
import AppKit
import Foundation
import SwiftData

// MARK: - 📦 导出数据结构 (DTO)

// 💡 架构设计说明：
// 这四个结构体专为导出跨平台兼容的 JSON 数据而设计。
// 由于 SwiftData 原生的 `@Model` 类包含了大量宏和内部代理变量，直接导出极易导致循环引用崩溃。
// 这层“无状态数据桥梁”将 SwiftData 对象转换为纯粹的、仅含基础类型的结构，方便外部系统解析。

/// 完整的数据备份压缩包根结构，涵盖时间戳和核心书籍列表。
struct ExportArchive: Codable {
    let exportTime: Date
    let totalBooks: Int
    let books: [ExportBook]
}

/// 针对单本书籍建立的脱水级扁平导出模型。
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
    /// 导出的图片封面将独立存放在 `Covers` 文件夹中，该字段建立关联映射的文件名。
    let coverFileName: String?
}

/// 脱水版的摘录记录 DTO。
struct ExportExcerpt: Codable {
    let content: String
    let createdAt: Date?
}

/// 脱水版的笔记随笔 DTO。
struct ExportNote: Codable {
    let content: String
    let createdAt: Date?
}

// MARK: - 🚀 核心导出引擎

/// 处理应用内产生的所有数据向物理硬盘导出的中枢服务类。
///
/// **职责与特性：**
/// 1. 利用 macOS 原生的 `NSOpenPanel` 获取安全的文件夹写入授权。
/// 2. 进行深度数据脱水转换（将 `@Model` 转至 `DTO`）。
/// 3. 通过内置编码器进行结构化 JSON 持久化以及海量封面的批量写入工作。
@MainActor
final class DataExportService {
    /// 全局导出服务单例
    static let shared = DataExportService()
    
    private init() {}
    
    /// 呼出 macOS 原生目录选择面板，执行全量阅读数据和封面图片的本地导出备份。
    ///
    /// - 流程细节：
    ///   1. 调起系统 `NSOpenPanel` 请求一个宿主文件夹。
    ///   2. 以当前系统时间创建带时间戳的专属二级根目录及并行的 `Covers` 子文件夹。
    ///   3. 扫描每本传入的书籍对象。若带有封面数据，则对其标题进行特殊字符过滤后输出图片至子文件夹。
    ///   4. 将对象结构转成 `DTO`，使用 `.prettyPrinted` 和标准化 ISO8601 时区算法进行规范化 JSON 序列写入。
    ///
    /// - Parameters:
    ///   - books: 需要被抽取导出的全量内部 SwiftData `Book` 对象合集。
    ///
    /// - Returns: 若任务全部执行完成，返回导出创建的根级文件夹 `URL` 以供其他调用层触发 Finder。如果用户中途取消则返回 `nil`。
    ///
    /// - Throws: 如果文件物理写入失败、JSON 解析异常、或者由于权限被阻断，则抛出底层系统错误。
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
