#if os(macOS) || os(iOS)
import Foundation
import SwiftData

@Model
final class BookAnnotation {
    var id: String = UUID().uuidString
    var content: String = ""
    var type: AnnotationType = AnnotationType.excerpt
    var createdAt: Date = Date()
    var book: Book?

    init(content: String, type: AnnotationType, createdAt: Date = Date(), book: Book? = nil) {
        self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type
        self.createdAt = createdAt
        self.book = book
    }

    var isNote: Bool { type == .note }
}
#endif
