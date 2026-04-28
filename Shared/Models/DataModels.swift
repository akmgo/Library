import Foundation
import SwiftUI
import SwiftData

// MARK: - 统一控制的常量与枚举 (Enum)

enum BookStatus: String, Codable, CaseIterable {
    case unread = "UNREAD"
    case reading = "READING"
    case finished = "FINISHED"
    case abandoned = "ABANDONED"
    case wantToRead = "WANT_TO_READ"
    
    var displayName: String {
        switch self {
        case .unread: return "未读"
        case .reading: return "在读"
        case .finished: return "已读"
        case .abandoned: return "弃读"
        case .wantToRead: return "想读"
        }
    }
}

// MARK: - 📜 摘录类别枚举

enum SnippetCategory: String, Codable, CaseIterable {
    case poetry = "POETRY"
    case lyric = "LYRIC"
    case prose = "PROSE"
    case quote = "QUOTE"
    case web = "WEB"
    case movie = "MOVIE"
    
    var displayName: String {
        switch self {
        case .poetry: return "诗歌"
        case .lyric: return "词曲"
        case .prose: return "短文"
        case .quote: return "语录"
        case .web: return "拾遗"
        case .movie: return "台词"
        }
    }
    
    var themeColor: Color {
        switch self {
        case .poetry, .lyric: return .orange
        case .prose: return .blue
        case .quote: return .purple
        case .movie: return .pink
        case .web: return .teal
        }
    }
}

// ✨ 新增：用于区分数据表内的数据是属于摘录还是笔记
enum AnnotationType: String, Codable {
    case excerpt = "EXCERPT"
    case note = "NOTE"
}

// MARK: - 核心实体模型 (Entities)

@Model
final class Book {
    var id: String = UUID().uuidString
    var title: String = ""
    var author: String = ""
    
    @Attribute(.externalStorage) var coverData: Data?
    
    var createdAt: Date = Date()
    
    var status: BookStatus = BookStatus.unread
    var rating: Int = 0
    var tags: [String] = []
    
    var startTime: Date?
    var endTime: Date?
    var progress: Double = 0.0
    
    // MARK: - 关联关系

    // ✨ 优化：现在书籍与批注属于简单、纯净的一对多关系
    @Relationship(deleteRule: .cascade, inverse: \BookAnnotation.book)
    var annotations: [BookAnnotation]?
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingRecord.book)
    var readingRecords: [ReadingRecord]?
    
    init(
        title: String,
        author: String,
        coverData: Data? = nil,
        createdAt: Date = Date(),
        status: BookStatus = .unread,
        rating: Int = 0,
        tags: [String] = [],
        startTime: Date? = nil,
        endTime: Date? = nil,
        progress: Double = 0.0
    ) {
        self.title = title
        self.author = author
        self.coverData = coverData
        self.status = status
        self.rating = rating
        self.tags = tags
        self.startTime = startTime
        self.endTime = endTime
        self.progress = progress
        self.createdAt = createdAt
    }
}

// MARK: - 📚 合并后的附属内容模型 (摘录 & 笔记二合一)

@Model
final class BookAnnotation {
    var id: String = UUID().uuidString
    var content: String = ""
    var createdAt: Date = Date()
    var type: AnnotationType = AnnotationType.excerpt // ✨ 类型标识
    
    var book: Book?
    
    init(content: String, type: AnnotationType, createdAt: Date = Date(), book: Book? = nil) {
        self.content = content
        self.type = type
        self.createdAt = createdAt
        self.book = book
    }
    
    // ✨ 快捷计算属性，方便 UI 层判断
    var isNote: Bool { type == .note }
}

@Model
final class ReadingRecord {
    var id: String = UUID().uuidString
    var date: Date = Date()
    var readingDuration: TimeInterval = 0
    var book: Book?
    
    init(date: Date = Date(), readingDuration: TimeInterval = 0, book: Book? = nil) {
        self.readingDuration = readingDuration
        self.book = book
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.date = calendar.date(from: components) ?? date
    }
}

@Model
final class UserConfig {
    var dailyReadingGoal: Int = 30
    var yearlyBookGoal: Int = 20
    var libraryTargetGoal: Int = 100
    var updatedAt: Date = Date()
    
    init(
        dailyReadingGoal: Int = 30,
        yearlyBookGoal: Int = 20,
        libraryTargetGoal: Int = 100,
        updatedAt: Date = Date()
    ) {
        self.dailyReadingGoal = dailyReadingGoal
        self.yearlyBookGoal = yearlyBookGoal
        self.libraryTargetGoal = libraryTargetGoal
        self.updatedAt = updatedAt
    }
}

@Model
final class Snippet {
    var id: String = UUID().uuidString
    var content: String = ""
    var title: String = ""
    var author: String = "佚名"
    var dynasty: String = ""
    var annotation: String = ""
    var category: SnippetCategory = SnippetCategory.web
    var addedDate: Date = Date()
        
    init(
        title: String = "无题",
        content: String,
        author: String = "佚名",
        dynasty: String = "",
        annotation: String = "",
        category: SnippetCategory = .web
    ) {
        self.title = title
        self.content = content
        self.author = author
        self.dynasty = dynasty
        self.annotation = annotation
        self.category = category
        self.addedDate = Date()
    }
}
