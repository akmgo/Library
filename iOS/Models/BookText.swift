import Foundation
import SwiftData

enum BookTextKind: String, CaseIterable, Identifiable, Codable {
    case excerpt
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .excerpt: "摘录"
        case .note: "笔记"
        }
    }
}

@Model
final class BookText {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var content: String
    var page: Int
    var createdAt: Date
    var book: Book?

    init(
        book: Book?,
        kind: BookTextKind,
        content: String,
        page: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        self.page = max(page, 0)
        self.createdAt = createdAt
        self.book = book
    }

    var kind: BookTextKind {
        get { BookTextKind(rawValue: kindRaw) ?? .excerpt }
        set { kindRaw = newValue.rawValue }
    }
}
