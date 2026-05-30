#if os(macOS) || os(iOS)
import Foundation
import SwiftData

@Model
final class Book {
    var id: String = UUID().uuidString
    var title: String = ""
    var author: String = ""

    @Attribute(.externalStorage) var coverData: Data?

    var createdAt: Date = Date()
    var status: BookStatus = BookStatus.unread
    var rating: Int = 0 {
        didSet { rating = min(max(rating, 0), 7) }
    }
    var tags: [String] = []

    var startDate: Date?
    var finishDate: Date?
    var lastReadAt: Date?

    var totalAmount: Double = 0 {
        didSet {
            totalAmount = max(totalAmount, 0)
            if totalAmount > 0 { currentAmount = min(currentAmount, totalAmount) }
        }
    }
    var currentAmount: Double = 0 {
        didSet {
            currentAmount = max(currentAmount, 0)
            if totalAmount > 0 { currentAmount = min(currentAmount, totalAmount) }
        }
    }

    var summary: String = ""

    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var sessions: [ReadingSession]?

    @Relationship(deleteRule: .cascade, inverse: \Excerpt.book)
    var excerpts: [Excerpt]?

    init(
        title: String,
        author: String = "",
        coverData: Data? = nil,
        createdAt: Date = Date(),
        status: BookStatus = .unread,
        rating: Int = 0,
        tags: [String] = [],
        startDate: Date? = nil,
        finishDate: Date? = nil,
        lastReadAt: Date? = nil,
        totalAmount: Double = 0,
        currentAmount: Double = 0,
        summary: String = "",
        sessions: [ReadingSession]? = nil,
        excerpts: [Excerpt]? = nil
    ) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        self.coverData = coverData
        self.createdAt = createdAt
        self.status = status
        self.rating = min(max(rating, 0), 7)
        self.tags = tags
        self.startDate = startDate
        self.finishDate = finishDate
        self.lastReadAt = lastReadAt
        self.totalAmount = max(totalAmount, 0)
        self.currentAmount = max(currentAmount, 0)
        if self.totalAmount > 0 { self.currentAmount = min(self.currentAmount, self.totalAmount) }
        self.summary = summary
        self.sessions = sessions
        self.excerpts = excerpts
    }

    var progressRatio: Double {
        guard totalAmount > 0 else { return 0 }
        return min(max(currentAmount / totalAmount, 0), 1)
    }

    var remainingAmount: Double {
        max(totalAmount - currentAmount, 0)
    }

    var isFinishedByProgress: Bool {
        totalAmount > 0 && currentAmount >= totalAmount
    }

    var displayProgress: String {
        "\(Int(currentAmount)) / \(Int(totalAmount)) 页"
    }

    var displayPercent: String {
        "\(Int(progressRatio * 100))%"
    }
}
#endif
