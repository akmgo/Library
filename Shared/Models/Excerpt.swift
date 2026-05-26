#if os(macOS) || os(iOS)
import Foundation
import SwiftData

@Model
final class Excerpt {
    var id: String = UUID().uuidString
    var content: String = ""
    var category: ExcerptCategory = ExcerptCategory.bookExcerpt
    var title: String?
    var sourceAuthor: String?
    var source: String?
    var createdAt: Date = Date()
    var book: Book?

    init(
        content: String,
        category: ExcerptCategory = .bookExcerpt,
        title: String? = nil,
        sourceAuthor: String? = nil,
        source: String? = nil,
        createdAt: Date = Date(),
        book: Book? = nil
    ) {
        self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        self.category = category
        self.title = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceAuthor = sourceAuthor?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.source = source?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.book = book
    }

    var isNote: Bool { category == .note }
    var categoryDisplayName: String { category.displayName }
    var displayTitle: String { title?.isEmpty == false ? title! : book?.title ?? category.displayName }
    var displayAuthor: String { sourceAuthor?.isEmpty == false ? sourceAuthor! : book?.author ?? "佚名" }

    var author: String {
        get { sourceAuthor ?? "佚名" }
        set { sourceAuthor = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    var addedDate: Date {
        get { createdAt }
        set { createdAt = newValue }
    }

    var annotation: String {
        get { source ?? "" }
        set { source = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    var dynasty: String {
        get { "" }
        set {}
    }

    var type: ExcerptCategory {
        get { category }
        set { category = newValue == .bookExcerpt ? .bookExcerpt : newValue }
    }

    convenience init(
        content: String,
        type: ExcerptCategory,
        createdAt: Date = Date(),
        book: Book? = nil
    ) {
        self.init(content: content, category: type == .bookExcerpt ? .bookExcerpt : type, createdAt: createdAt, book: book)
    }

    convenience init(
        title: String = "无题",
        content: String,
        author: String = "佚名",
        dynasty: String = "",
        annotation: String = "",
        category: ExcerptCategory = .web
    ) {
        self.init(
            content: content,
            category: category,
            title: title,
            sourceAuthor: author,
            source: annotation
        )
    }
}

#endif
