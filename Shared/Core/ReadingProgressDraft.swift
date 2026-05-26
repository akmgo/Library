#if os(macOS) || os(iOS)
import Foundation

struct ReadingProgressDraft: Equatable {
    var unit: ProgressUnit
    var totalAmount: Double
    var currentAmount: Double

    init(
        unit: ProgressUnit = .percent,
        totalAmount: Double = 100,
        currentAmount: Double = 0
    ) {
        self.unit = unit
        self.totalAmount = max(totalAmount, 0)
        self.currentAmount = max(currentAmount, 0)
        normalize()
    }

    static var bookImportDefault: ReadingProgressDraft {
        ReadingProgressDraft(unit: .percent, totalAmount: 100, currentAmount: 0)
    }

    static func sessionDefault(for book: Book) -> ReadingProgressDraft {
        ReadingProgressDraft(
            unit: book.progressUnit,
            totalAmount: normalizedTotal(for: book.progressUnit, total: book.totalAmount),
            currentAmount: book.currentAmount
        )
    }

    var isValidForBookImport: Bool {
        switch unit {
        case .percent:
            return totalAmount == 100
        case .page, .chapter:
            return totalAmount > 0
        }
    }

    var isValidForSessionUpdate: Bool {
        totalAmount > 0 && currentAmount >= 0 && currentAmount <= totalAmount
    }

    mutating func setUnit(_ newUnit: ProgressUnit, currentBookAmount: Double = 0) {
        unit = newUnit
        totalAmount = Self.normalizedTotal(for: newUnit, total: totalAmount)
        currentAmount = min(max(currentAmount, currentBookAmount), totalAmount)
        normalize()
    }

    mutating func normalize() {
        totalAmount = Self.normalizedTotal(for: unit, total: totalAmount)
        currentAmount = min(max(currentAmount, 0), totalAmount)
    }

    static func normalizedTotal(for unit: ProgressUnit, total: Double) -> Double {
        switch unit {
        case .percent:
            return 100
        case .page, .chapter:
            return max(total.rounded(), 0)
        }
    }
}
#endif
