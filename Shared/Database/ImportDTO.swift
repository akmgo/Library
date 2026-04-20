import Foundation

// MARK: - JSON 数据传输对象 (DTO)
// 💡 设计理念：DTO 专门用于解耦外部导入的 JSON 数据与内部的 SwiftData @Model。
// 它们是扁平的、无状态的结构体，避免了反序列化时复杂的上下文依赖。

/// 用于接收外部导入的书籍元数据的数据传输对象。
struct BookImportDTO: Codable, Identifiable {
    /// 唯一标识，缺省使用书名作为主键映射。
    var id: String { title }
    
    let title: String
    let author: String
    
    /// 书籍阅读状态的原始字符串，预期值为 "UNREAD", "READING", "FINISHED" 等。
    let status: String?
    let rating: Int?         // 1~5
    let tags: [String]?      // ["哲学", "历史"]
    let startTime: Date?     // ISO8601 格式
    let endTime: Date?
    let progress: Int?
    let isWantToRead: Bool?
}

/// 用于接收外部导入的精彩摘录的数据传输对象。
struct ExcerptImportDTO: Codable, Identifiable {
    var id: String { UUID().uuidString }
    
    /// 摘录的纯文本内容。
    let content: String
    let createdAt: Date?     // 选填
    
    /// 目标书籍名称，导入引擎会据此自动寻找并在 SwiftData 中建立关联 (Relationship)。
    let bookTitle: String?   // 选填：用于自动吸附到某本书
}

/// 用于接收外部导入的读书笔记的数据传输对象。
struct NoteImportDTO: Codable, Identifiable {
    var id: String { UUID().uuidString }
    let content: String
    let createdAt: Date?     // 选填
    let bookTitle: String?   // 选填：用于自动吸附到某本书
}

/// 用于接收外部导入的历史打卡记录的数据传输对象。
struct ReadingRecordImportDTO: Codable, Identifiable {
    var id: String { UUID().uuidString }
    
    /// 必填参数：完成打卡的具体日期，解析引擎会抹平其时分秒。
    let date: Date
    
    /// 选填参数：单次打卡专注的时长 (单位：秒，比如半小时填 1800)。
    let duration: Double?
    let bookTitle: String?   // 选填：如果这天读了某本书，就填书名
}
