import Foundation
import SwiftData

// MARK: - 统一控制的常量与枚举 (Enum)

/// 标识书籍当前生命周期的枚举。
///
/// 遵循 `Codable`，底层通过字符串持久化到 SQLite 中。
enum BookStatus: String, Codable, CaseIterable {
    /// 尚未开始阅读的书籍（在想读队列中）。
    case unread = "UNREAD"
    /// 当前正在进行焦点计时或阅读的书籍。
    case reading = "READING"
    /// 已经读完的书籍（将被计入年度成就）。
    case finished = "FINISHED"
    /// 放弃阅读的书籍。
    case abandoned = "ABANDONED"
    
    /// 用于前端 UI 展示的本地化中文标签。
    var displayName: String {
        switch self {
        case .unread: return "未读"
        case .reading: return "在读"
        case .finished: return "已读"
        case .abandoned: return "弃读"
        }
    }
}

// MARK: - 核心实体模型 (Entities)

/// 核心数据模型：代表用户书架上的一本书（对应底层 SQLite 数据库的 Books 表）。
///
/// 它是整个架构的中心节点（Hub）。一本书可以拥有多条 `ReadingRecord`（打卡记录）、
/// 多条 `Excerpt`（摘录）和多条 `Note`（笔记）。
///
/// - 注意: `coverData` 字段使用了 `@Attribute(.externalStorage)`，
/// 确保大型图片数据被存放在沙盒文件系统中，维持 SQLite 查询的极速性能。
@Model
final class Book {
    // 基础信息
    var id: String?
    var title: String?
    var author: String?
    
    /// 书籍封面原始二进制数据。由于体积较大，底层映射于外部沙盒存储。
    @Attribute(.externalStorage) var coverData: Data?
    
    // 状态与分类
    var status: BookStatus?
    var rating: Int?
    var tags: [String]?
    
    // 阅读进度与时间
    var startTime: Date?
    var endTime: Date?
    var progress: Int = 0
    var isWantToRead: Bool = false
    
    // MARK: - 关联关系 (Relationships)
    
    /// 书中保存的精彩摘录集合。
    /// 级联删除 (`.cascade`) 意味着：若删除本书，它关联的所有摘录也将被一同销毁。
    @Relationship(deleteRule: .cascade, inverse: \Excerpt.book)
    var excerpts: [Excerpt]?
    
    /// 该书的历史阅读打卡时间记录。
    @Relationship(deleteRule: .cascade, inverse: \ReadingRecord.book)
    var readingRecords: [ReadingRecord]?
    
    /// 用户为本书撰写的随笔与笔记。
    @Relationship(deleteRule: .cascade, inverse: \Note.book)
    var notes: [Note]?
    
    // MARK: - 初始化
    
    init(
        id: String = UUID().uuidString,
        title: String,
        author: String,
        coverData: Data? = nil,
        status: BookStatus = .unread,
        rating: Int = 0,
        tags: [String] = [],
        startTime: Date? = nil,
        endTime: Date? = nil,
        progress: Int = 0,
        isWantToRead: Bool = false
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.coverData = coverData
        self.status = status
        self.rating = rating
        self.tags = tags
        self.startTime = startTime
        self.endTime = endTime
        self.progress = progress
        self.isWantToRead = isWantToRead
    }
}

// MARK: - 附属内容模型

/// 摘录数据模型：对应书中的精彩原文划线。
@Model
final class Excerpt {
    var id: String?
    var content: String?
    var createdAt: Date?
    
    /// 指向当前摘录所属书籍的引用引用关系。
    var book: Book?
    
    init(id: String = UUID().uuidString, content: String, createdAt: Date = Date(), book: Book? = nil) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.book = book
    }
}

/// 笔记数据模型：对应用户的原创心得。
@Model
final class Note {
    var id: String?
    var content: String?
    var createdAt: Date?
    var book: Book?
    
    init(id: String = UUID().uuidString, content: String, createdAt: Date = Date(), book: Book? = nil) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.book = book
    }
}

/// 每日阅读打卡流水模型。
///
/// 该模型用于驱动主页的“双周动能图”和“年度热力图”。
///
/// - 注意: 每次初始化时，它都会自动利用 `Calendar` 抹去时分秒，仅保留当天的零点时间 (`yyyy-MM-dd 00:00:00`)，
/// 这对于后续按照“日”维度进行 `Group By` 聚合计算至关重要。
@Model
final class ReadingRecord {
    var id: String?
    
    /// 标准化到当日零点的时间戳。
    var date: Date?
    
    /// 本次/本日累积阅读的总时长，单位为秒 (Seconds)。
    var readingDuration: TimeInterval = 0
    
    /// 产生该专注时长的目标书籍。
    var book: Book?
    
    init(date: Date = Date(), readingDuration: TimeInterval = 0, book: Book? = nil) {
        self.id = UUID().uuidString
        self.readingDuration = readingDuration
        self.book = book
        
        // 抹去具体的时间（时分秒），只保留年月日。保证后续可基于日期作精准聚合。
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.date = calendar.date(from: components) ?? date
    }
}

/// 用户偏好配置数据模型。
///
/// 用于存储跨设备的个人阅读目标、主题设定等。
@Model
final class UserConfig {
    var dailyReadingGoal: Int = 30
    var yearlyBookGoal: Int = 50
    var libraryTargetGoal: Int = 500
    var appTheme: String = "system"
    var updatedAt: Date = Date()
    
    init(
        dailyReadingGoal: Int = 30,
        yearlyBookGoal: Int = 50,
        libraryTargetGoal: Int = 500,
        appTheme: String = "system",
        updatedAt: Date = Date()
    ) {
        self.dailyReadingGoal = dailyReadingGoal
        self.yearlyBookGoal = yearlyBookGoal
        self.libraryTargetGoal = libraryTargetGoal
        self.appTheme = appTheme
        self.updatedAt = updatedAt
    }
}
