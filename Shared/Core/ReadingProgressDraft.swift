#if os(macOS) || os(iOS)
import Foundation

struct ReadingProgressDraft: Equatable {
    var totalAmount: Double
    var currentAmount: Double

    init(totalAmount: Double = 0, currentAmount: Double = 0) {
        self.totalAmount = max(totalAmount, 0)
        self.currentAmount = max(currentAmount, 0)
        normalize()
    }

    static var bookImportDefault: ReadingProgressDraft {
        ReadingProgressDraft()
    }

    static func sessionDefault(for book: Book) -> ReadingProgressDraft {
        ReadingProgressDraft(
            totalAmount: book.totalAmount,
            currentAmount: book.currentAmount
        )
    }

    var isValidForBookImport: Bool {
        totalAmount > 0
    }

    var isValidForSessionUpdate: Bool {
        totalAmount > 0 && currentAmount >= 0 && currentAmount <= totalAmount
    }

    mutating func normalize() {
        totalAmount = max(totalAmount.rounded(), 0)
        currentAmount = min(max(currentAmount, 0), totalAmount)
    }
}
#endif
