#if os(macOS) || os(iOS)
import Foundation

enum ReadingValidation {
    static func clampedRating(_ rating: Int) -> Int {
        min(max(rating, 0), 7)
    }

    static func clampedAmount(_ amount: Double, total: Double = 0) -> Double {
        let positiveAmount = max(amount, 0)
        return total > 0 ? min(positiveAmount, total) : positiveAmount
    }

    static func normalizedDuration(startedAt: Date, endedAt: Date) -> TimeInterval {
        max(endedAt.timeIntervalSince(startedAt), 0)
    }

    static func trimmedRequiredText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
