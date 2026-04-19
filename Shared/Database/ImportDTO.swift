import Foundation

// MARK: - 1. 藏书导入 DTO
struct BookImportDTO: Codable, Identifiable {
    var id: String { title }
    let title: String
    let author: String
    let status: String?      // "UNREAD", "READING", "FINISHED"
    let rating: Int?         // 1~5
    let tags: [String]?      // ["哲学", "历史"]
    let startTime: Date?     // ISO8601 格式
    let endTime: Date?
    let progress: Int?
    let isWantToRead: Bool?
}

// MARK: - 2. 摘录导入 DTO (书中的原话)
struct ExcerptImportDTO: Codable, Identifiable {
    var id: String { UUID().uuidString }
    let content: String
    let createdAt: Date?     // 选填
    let bookTitle: String?   // 选填：用于自动吸附到某本书
}

// MARK: - 3. 笔记导入 DTO (自己的感悟)
struct NoteImportDTO: Codable, Identifiable {
    var id: String { UUID().uuidString }
    let content: String
    let createdAt: Date?     // 选填
    let bookTitle: String?   // 选填：用于自动吸附到某本书
}

// MARK: - 4. 阅读记录导入 DTO (历史打卡数据)
struct ReadingRecordImportDTO: Codable, Identifiable {
    var id: String { UUID().uuidString }
    let date: Date           // 必填：打卡日期 (ISO8601)
    let duration: Double?    // 选填：专注时长 (单位：秒，比如半小时填 1800)
    let bookTitle: String?   // 选填：如果这天读了某本书，就填书名
}
