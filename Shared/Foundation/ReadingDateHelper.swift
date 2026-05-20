#if os(macOS) || os(iOS)
import Foundation

enum ReadingDateHelper {
    static func startOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func daysEnding(at endDate: Date = Date(), count: Int, calendar: Calendar = .current) -> [Date] {
        guard count > 0 else { return [] }
        let end = calendar.startOfDay(for: endDate)
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: end)
        }
    }
}
#endif
