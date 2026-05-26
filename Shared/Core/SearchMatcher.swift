#if os(macOS) || os(iOS)
import Foundation

enum SearchMatcher {
    static func matchesBook(_ book: Book, query: String) -> Bool {
        matches(query, in: [book.title, book.author] + book.tags)
    }

    static func matchesExcerpt(_ excerpt: Excerpt, query: String) -> Bool {
        if let book = excerpt.book {
            return matches(query, in: [
                excerpt.content,
                excerpt.category.displayName,
                book.title
            ])
        }

        return matches(query, in: [
            excerpt.content,
            excerpt.category.displayName,
            excerpt.displayTitle,
            excerpt.displayAuthor
        ])
    }

    static func matches(_ query: String, in fields: [String?]) -> Bool {
        let tokens = queryTokens(query)
        guard !tokens.isEmpty else { return false }

        let searchableFields = fields
            .compactMap { normalized($0) }
            .filter { !$0.isEmpty }

        guard !searchableFields.isEmpty else { return false }

        return tokens.allSatisfy { token in
            searchableFields.contains { field in
                field.contains(token)
            }
        }
    }

    static func queryTokens(_ query: String) -> [String] {
        normalized(query)?
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty } ?? []
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let folded = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()

        guard !folded.isEmpty else { return nil }
        return folded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
#endif
