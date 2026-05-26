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

    static func normalizedManualSession(
        startedAt: Date,
        duration: TimeInterval,
        calendar: Calendar = .current
    ) -> (date: Date, endedAt: Date, duration: TimeInterval) {
        let safeDuration = max(duration, 0)
        return (
            date: calendar.startOfDay(for: startedAt),
            endedAt: startedAt.addingTimeInterval(safeDuration),
            duration: safeDuration
        )
    }

    static func trimmedRequiredText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
