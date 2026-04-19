import Foundation
import SwiftData

// MARK: - 统一控制的常量与枚举 (Enum)

/// 书籍阅读状态枚举
/// 遵循 Codable 以便存入数据库，String 类型代表底层存的是字符串
enum BookStatus: String, Codable, CaseIterable {
    case unread = "UNREAD"       // 未读
    case reading = "READING"     // 在读
    case finished = "FINISHED"   // 已读
    case abandoned = "ABANDONED" // 弃读（为你未来可能的功能留个口子）
    
    // 你可以直接在这里写些辅助方法，比如 UI 显示的中文名字
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

/// 书籍模型对象 (对应数据库 Books 表)
@Model
final class Book {
    // 基础信息
    var id: String?
    var title: String?
    var author: String?
    
    // ✨ 只有这个字段负责存封面，.externalStorage 告诉底层把大文件存在沙盒文件系统，而不是塞爆 SQLite
    @Attribute(.externalStorage) var coverData: Data?
    
    // 状态与分类
    var status: BookStatus? // 使用枚举替换魔法字符串
    var rating: Int?
    var tags: [String]?
    
    // 阅读进度与时间
    var startTime: Date?
    var endTime: Date?
    var progress: Int = 0
    var isWantToRead: Bool = false
    
    // MARK: - 关联关系 (Relationships)
    // 类比 Java 里的 @OneToMany(cascade = CascadeType.ALL)
    // deleteRule: .cascade 意味着：删了这本书，它底下的所有笔记、摘录都会跟着被销毁，防止产生孤儿数据
    
    // ⚠️ SwiftData 最佳实践：指明反向关系 (inverse)。这样双向绑定更牢固
    @Relationship(deleteRule: .cascade, inverse: \Excerpt.book)
    var excerpts: [Excerpt]?
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingRecord.book)
    var readingRecords: [ReadingRecord]? // 变量名遵循驼峰命名法，改成了 readingRecords
    
    @Relationship(deleteRule: .cascade, inverse: \Note.book)
    var notes: [Note]?
    
    // MARK: - 初始化
    init(
        id: String = UUID().uuidString,
        title: String,
        author: String,
        coverData: Data? = nil,
        status: BookStatus = .unread, // 默认状态为枚举值
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
        self.isWantToRead = isWantToRead // 🐛 Bug 修复：不再写死 false
    }
}

// MARK: - 附属内容模型

/// 摘录模型 (对应书中划线的精彩句子)
@Model
final class Excerpt {
    var id: String?
    var content: String?
    var createdAt: Date?
    
    var book: Book? // 多对一关系：这条摘录属于哪本书
    
    init(id: String = UUID().uuidString, content: String, createdAt: Date = Date(), book: Book? = nil) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.book = book
    }
}

/// 随笔/笔记模型
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

/// 每日阅读打卡记录
@Model
final class ReadingRecord {
    var id: String?
    var date: Date? // 打卡日期
    var readingDuration: TimeInterval = 0 // 阅读时长 (秒)
    var book: Book? // 关联的在读书籍（可以为空，代表仅泛泛打卡，没特指哪本书）
    
    init(date: Date = Date(), readingDuration: TimeInterval = 0, book: Book? = nil) {
        self.id = UUID().uuidString
        self.readingDuration = readingDuration
        self.book = book
        
        // 抹去具体的时间（时分秒），只保留年月日。保证一天只有一条记录或方便聚合
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.date = calendar.date(from: components) ?? date
    }
}

@Model
final class UserConfig {
    // ✨ 核心修复：必须在这里直接赋予默认值！这是 CloudKit 强制要求的“安全底线”
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
