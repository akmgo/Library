import Foundation
import SwiftData

@Model
final class ReadingLog {
    @Attribute(.unique) var id: UUID
    var date: Date
    var minutes: Int
    var pageAfterReading: Int
    var createdAt: Date
    var book: Book?

    init(
        book: Book?,
        date: Date = Date(),
        minutes: Int,
        pageAfterReading: Int = 0
    ) {
        self.id = UUID()
        self.book = book
        self.date = date
        self.minutes = max(minutes, 1)
        self.pageAfterReading = max(pageAfterReading, 0)
        self.createdAt = Date()
    }
}
