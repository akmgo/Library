#if os(macOS) || os(iOS)
import Foundation
import SwiftData

@MainActor
final class LocalBookManager {
    static let shared = LocalBookManager()

    private init() {}

    func deleteBook(_ book: Book, context: ModelContext) {
        context.delete(book)
    }
}
#endif
