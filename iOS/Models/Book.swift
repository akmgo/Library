import Foundation
import SwiftData

enum BookStatus: String, CaseIterable, Identifiable, Codable {
    case planned
    case reading
    case finished

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planned: "待读"
        case .reading: "在读"
        case .finished: "已读"
        }
    }
}

@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var publisher: String
    var createdAt: Date
    var startDate: Date?
    var finishDate: Date?
    var statusRaw: String
    var totalPages: Int
    var currentPage: Int
    var rating: Int

    @Attribute(.externalStorage) var coverData: Data?

    @Relationship(deleteRule: .cascade, inverse: \ReadingLog.book)
    var logs: [ReadingLog]

    @Relationship(deleteRule: .cascade, inverse: \BookText.book)
    var texts: [BookText]

    init(
        title: String,
        author: String = "",
        publisher: String = "",
        status: BookStatus = .planned,
        totalPages: Int = 0,
        currentPage: Int = 0,
        rating: Int = 0,
        coverData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        self.publisher = publisher.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.startDate = nil
        self.finishDate = nil
        self.statusRaw = status.rawValue
        self.totalPages = max(totalPages, 0)
        self.currentPage = min(max(currentPage, 0), max(totalPages, 0))
        self.rating = min(max(rating, 0), 7)
        self.coverData = coverData
        self.logs = []
        self.texts = []
    }

    var status: BookStatus {
        get { BookStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(max(Double(currentPage) / Double(totalPages), 0), 1)
    }

    var progressText: String {
        totalPages > 0 ? "\(currentPage)/\(totalPages)" : "未设置页数"
    }

    var totalReadingMinutes: Int {
        logs.reduce(0) { $0 + $1.minutes }
    }

    var lastReadAt: Date? {
        logs.map(\.date).max()
    }
}
