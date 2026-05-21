#if os(macOS) || os(iOS)
import Foundation
import SwiftData

@MainActor
final class ReadingDataService {
    static let shared = ReadingDataService()

    private init() {}

    func insertBook(_ book: Book, context: ModelContext) throws {
        normalizeBook(book)
        context.insert(book)
        try context.save()
    }

    func deleteBook(_ book: Book, context: ModelContext) {
        context.delete(book)
    }

    func deleteBookAndSave(_ book: Book, context: ModelContext) throws {
        deleteBook(book, context: context)
        try context.save()
    }

    func deleteBooks(_ books: [Book], context: ModelContext) throws {
        books.forEach { deleteBook($0, context: context) }
        try context.save()
    }

    func updateStatus(
        _ book: Book,
        to newStatus: BookStatus,
        at date: Date = Date(),
        markFinishedProgress: Bool = true,
        resetProgressWhenUnread: Bool = true,
        context: ModelContext? = nil
    ) throws {
        let oldStatus = book.status
        guard oldStatus != newStatus else {
            if let context { try context.save() }
            return
        }

        book.status = newStatus
        switch newStatus {
        case .reading:
            if book.startDate == nil { book.startDate = date }
            book.lastReadAt = date
            if book.finishDate != nil { book.finishDate = nil }
        case .finished:
            if book.startDate == nil { book.startDate = date }
            if book.finishDate == nil { book.finishDate = date }
            book.lastReadAt = date
            if markFinishedProgress, book.totalAmount > 0 {
                book.currentAmount = book.totalAmount
            }
        case .unread:
            if resetProgressWhenUnread {
                book.currentAmount = 0
                book.startDate = nil
                book.finishDate = nil
                book.lastReadAt = nil
            }
        case .planned:
            book.finishDate = nil
            if resetProgressWhenUnread {
                book.currentAmount = 0
                book.startDate = nil
                book.lastReadAt = nil
            }
        case .abandoned:
            book.finishDate = nil
        }

        normalizeBook(book)
        if let context { try context.save() }
    }

    func markBookStartedFromQueue(_ book: Book, context: ModelContext, at date: Date = Date()) throws {
        try updateStatus(
            book,
            to: .reading,
            at: date,
            markFinishedProgress: false,
            resetProgressWhenUnread: false,
            context: context
        )
    }

    func insertManualReadingSession(
        for book: Book,
        startedAt: Date,
        duration: TimeInterval,
        progressUnit: ProgressUnit,
        startAmount: Double,
        endAmount: Double,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws {
        let normalized = ReadingValidation.normalizedManualSession(
            startedAt: startedAt,
            duration: duration,
            calendar: calendar
        )
        let safeStart = ReadingValidation.clampedAmount(startAmount, total: book.totalAmount)
        let safeEnd = ReadingValidation.clampedAmount(endAmount, total: book.totalAmount)

        let session = ReadingSession(
            date: normalized.date,
            inputMode: .manual,
            startedAt: startedAt,
            endedAt: normalized.endedAt,
            duration: normalized.duration,
            progressUnit: progressUnit,
            startAmount: safeStart,
            endAmount: max(safeEnd, safeStart),
            book: book
        )

        context.insert(session)
        book.lastReadAt = startedAt
        book.progressUnit = progressUnit
        book.currentAmount = max(book.currentAmount, session.endAmount)
        if book.status == .unread || book.status == .planned {
            try updateStatus(
                book,
                to: .reading,
                at: startedAt,
                markFinishedProgress: false,
                resetProgressWhenUnread: false
            )
        } else {
            normalizeBook(book)
        }

        try context.save()
    }

    func insertExcerpt(
        content: String,
        category: ExcerptCategory,
        book: Book?,
        context: ModelContext
    ) throws {
        let text = ReadingValidation.trimmedRequiredText(content)
        guard !text.isEmpty else { return }
        context.insert(Excerpt(content: text, category: category, book: book))
        try context.save()
    }

    func deleteExcerpt(_ excerpt: Excerpt, context: ModelContext) throws {
        context.delete(excerpt)
        try context.save()
    }

    func insertExcerpt(_ excerpt: Excerpt, context: ModelContext) throws {
        context.insert(excerpt)
        try context.save()
    }

    func deleteExcerpts(_ excerpts: [Excerpt], context: ModelContext) throws {
        excerpts.forEach { context.delete($0) }
        try context.save()
    }

    func normalizeBook(_ book: Book) {
        book.title = ReadingValidation.trimmedRequiredText(book.title)
        book.author = ReadingValidation.trimmedRequiredText(book.author)
        book.rating = ReadingValidation.clampedRating(book.rating)
        book.totalAmount = ReadingValidation.clampedAmount(book.totalAmount)
        book.currentAmount = ReadingValidation.clampedAmount(book.currentAmount, total: book.totalAmount)
        book.tags = book.tags
            .map { ReadingValidation.trimmedRequiredText($0) }
            .filter { !$0.isEmpty }
    }
}
#endif
